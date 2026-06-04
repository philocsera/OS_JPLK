#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path

from groq import Groq

DEFAULT_MODEL = "openai/gpt-oss-120b"

PROPOSAL_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "action": {
            "type": "string",
            "enum": [
                "no_action",
                "keep_quota",
                "increase_quota",
                "decrease_quota",
                "release_quota",
                "swapout",
                "inspect_process",
            ],
        },
        "target_pid": {
            "type": "integer",
        },
        "target_quota": {
            "type": ["integer", "null"],
        },
        "swapout_pages": {
            "type": ["integer", "null"],
        },
        "diagnosis": {
            "type": "string",
        },
        "reason": {
            "type": "string",
        },
        "confidence": {
            "type": "string",
            "enum": [
                "low",
                "medium",
                "high",
            ],
        },
    },
    "required": [
        "action",
        "target_pid",
        "target_quota",
        "swapout_pages",
        "diagnosis",
        "reason",
        "confidence",
    ],
}


def call_groq(prompt, model, reasoning_effort):
    api_key = os.environ.get("GROQ_API_KEY")

    if not api_key:
        raise ValueError("GROQ_API_KEY environment variable is missing")

    client = Groq(api_key=api_key)

    response = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are an xv6 memory policy advisor. "
                    "Recommend exactly one safe runtime policy candidate. "
                    "Do not execute commands. "
                    "Use only the allowed actions provided in the prompt."
                ),
            },
            {
                "role": "user",
                "content": prompt,
            },
        ],
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "xv6_memory_policy_proposal",
                "strict": True,
                "schema": PROPOSAL_SCHEMA,
            },
        },
        reasoning_effort=reasoning_effort,
        temperature=0,
        max_completion_tokens=2048,
    )

    content = response.choices[0].message.content

    if not content:
        raise ValueError("Groq returned an empty response")

    return json.loads(content)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high"],
        default="medium",
    )
    args = parser.parse_args()

    prompt_path = Path(args.prompt)
    out_path = Path(args.out)

    if not prompt_path.exists():
        raise SystemExit(
            f"[groq] ERROR: prompt file not found: {prompt_path}"
        )

    try:
        proposal = call_groq(
            prompt_path.read_text(encoding="utf-8"),
            args.model,
            args.reasoning_effort,
        )
    except Exception as error:
        raise SystemExit(f"[groq] ERROR: {error}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(proposal, indent=2) + "\n",
        encoding="utf-8",
    )

    print("[groq] proposal received")
    print(f"[groq] model: {args.model}")
    print(f"[groq] output: {out_path}")
    print(json.dumps(proposal, indent=2))


if __name__ == "__main__":
    main()	
