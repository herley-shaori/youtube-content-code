"""Answers leave policy questions, either offline (default) or with Amazon Bedrock."""
import os
import re
from pathlib import Path

HERE = Path(__file__).parent
POLICY = (HERE / "policy.md").read_text()
SYSTEM_PROMPT = (HERE / "prompt.md").read_text() + "\n\n" + POLICY
MODEL_ID = os.environ.get("MODEL_ID", "amazon.nova-lite-v1:0")
MAX_QUESTION_LENGTH = 500
_STOPWORDS = {"leave", "days", "paid", "employee", "employees", "what", "does", "have", "with", "when", "much", "many"}


def mode():
    # "local" never calls AWS; the deployed Lambda sets ASSISTANT_MODE=bedrock.
    return os.environ.get("ASSISTANT_MODE", "local")


def answer(question):
    return _ask_bedrock(question) if mode() == "bedrock" else _ask_local(question)


def _words(text):
    return {w for w in re.findall(r"[a-z]+", text.lower()) if len(w) > 3} - _STOPWORDS


def _ask_local(question):
    # ponytail: keyword overlap, not real language understanding; Bedrock mode is the real thing.
    sections = POLICY.split("\n## ")[1:]
    asked = _words(question)
    best = max(sections, key=lambda s: len(asked & _words(s)))
    if not asked & _words(best):
        return "I can only answer questions about the Example Corp leave policy. Please contact HR."
    title, _, text = best.partition("\n")
    return f"{title}: {text.strip()}"


def _ask_bedrock(question):
    import boto3  # Bundled in the Lambda runtime; not needed for local mode.

    client = boto3.client("bedrock-runtime", region_name=os.environ.get("AWS_REGION", "ap-southeast-3"))
    response = client.converse(
        modelId=MODEL_ID,
        system=[{"text": SYSTEM_PROMPT}],
        messages=[{"role": "user", "content": [{"text": question}]}],
        inferenceConfig={"maxTokens": 400, "temperature": 0.2},
    )
    return response["output"]["message"]["content"][0]["text"]
