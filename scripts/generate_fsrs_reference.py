"""Regenerate the deterministic vocabulary scheduler fixture with fsrs==6.3.3."""

from datetime import datetime, timedelta, timezone
from importlib.metadata import version
import json
from pathlib import Path

from fsrs import Card, Rating, Scheduler


def scenario(name, ratings_at_hours, *, retention=90, cap=180, state=None):
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    scheduler = Scheduler(
        desired_retention=retention / 100,
        maximum_interval=cap,
        learning_steps=(),
        relearning_steps=(),
        enable_fuzzing=False,
    )
    if state is None:
        card = Card(card_id=1, due=start)
    else:
        card = Card.from_dict(
            {
                "card_id": 1,
                "state": 2,
                "step": None,
                "stability": state["stability"],
                "difficulty": state["difficulty"],
                "due": start.isoformat(),
                "last_review": start.isoformat(),
            }
        )
        state = {**state, "last_review": start.isoformat()}
    ratings = []
    for hours, grade in ratings_at_hours:
        moment = start + timedelta(hours=hours)
        card, _ = scheduler.review_card(
            card, Rating[grade.capitalize()], review_datetime=moment
        )
        ratings.append(
            {
                "at": moment.isoformat(),
                "rating": grade,
                "stability": card.stability,
                "difficulty": card.difficulty,
                "days": (card.due - moment).days,
                "due": card.due.isoformat(),
            }
        )
    return {
        "name": name,
        "retention": retention,
        "cap": cap,
        "initial": state,
        "ratings": ratings,
    }


def main():
    reference_version = "6.3.3"
    if version("fsrs") != reference_version:
        raise SystemExit(f"Install fsrs=={reference_version} first")
    fixture = {
        "reference": f"Py-FSRS {reference_version}",
        "generate": "python scripts/generate_fsrs_reference.py",
        "scenarios": [
            *(
                scenario(f"first {grade}", [(0, grade)])
                for grade in ("again", "hard", "good", "easy")
            ),
            scenario("same day hard", [(0, "good"), (12, "hard")]),
            scenario("early hard", [(0, "good"), (24, "hard")]),
            scenario("on time then overdue", [(0, "good"), (48, "good"), (720, "hard")]),
            scenario("lapse then delayed retry", [(0, "easy"), (240, "again"), (264, "good"), (500, "easy")]),
            scenario("cap 180", [(24, "easy")], state={"stability": 275, "difficulty": 4}),
            scenario("one day cap", [(0, "easy"), (24, "good")], cap=1),
            scenario("70% retention", [(0, "good"), (144, "good")], retention=70, cap=36500),
            scenario("97% retention", [(0, "good"), (144, "good")], retention=97, cap=36500),
            scenario("half to even", [(0, "hard")], state={"stability": 2.5, "difficulty": 4}),
        ],
    }
    output = Path(__file__).resolve().parents[1] / "test/fixtures/fsrs_reference.json"
    output.write_text(json.dumps(fixture, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
