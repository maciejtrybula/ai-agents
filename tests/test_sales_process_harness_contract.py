import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / ".claude" / "skills" / "sales-process-harness"
SCORECARD = SKILL / "references" / "scoring.md"
SKILL_MARKDOWN = SKILL / "SKILL.md"
EVALS = SKILL / "evals" / "evals.json"
EVAL_MIRRORS = (
    EVALS,
    ROOT / ".codex" / "skills" / "sales-process-harness" / "evals" / "evals.json",
    ROOT / ".config" / "opencode" / "skills" / "sales-process-harness" / "evals" / "evals.json",
)


def normalized(text):
    return re.sub(r"\s+", " ", text.replace("`", ""))


class SalesProcessHarnessContractTest(unittest.TestCase):
    def test_scorecard_has_the_expected_seven_dimensions_and_weights(self):
        scorecard = SCORECARD.read_text(encoding="utf-8")
        dimensions = re.findall(
            r"(?m)^- \*\*(?P<name>.+?) \((?P<weight>\d+)%\):\*\*",
            scorecard,
        )

        self.assertEqual(
            [name for name, _ in dimensions],
            [
                "Outcome/problem clarity",
                "Evidenced capability fit",
                "Solution/delivery feasibility",
                "Buying process/stakeholders/timing",
                "Differentiation/competition",
                "Commercial viability",
                "Pursuit effort relative to value/reuse",
            ],
        )
        self.assertEqual(sum(int(weight) for _, weight in dimensions), 100)

    def test_unknowns_are_excluded_from_score_and_reported_as_coverage(self):
        scorecard = normalized(SCORECARD.read_text(encoding="utf-8"))

        self.assertIn(
            "Exclude unknown dimensions from both numerator and denominator",
            scorecard,
        )
        self.assertRegex(
            scorecard,
            r"weighted score = sum\(weight_i × rating_i for i in A\)"
            r"\s*/\s*sum\(weight_i for i in A\)",
        )
        self.assertRegex(
            scorecard,
            r"weighted evidence coverage = sum\(weight_i for i in A\)"
            r"\s*/\s*100 × 100%",
        )
        self.assertIn("Coverage uses the full 100% rubric", scorecard)
        self.assertRegex(
            scorecard,
            r"If no dimension is assessable, show score N/A, coverage 0%",
        )

    def test_recommendations_do_not_block_artifacts_or_take_user_control(self):
        skill = normalized(SKILL_MARKDOWN.read_text(encoding="utf-8")).lower()

        self.assertRegex(
            skill,
            r"poor scores and no-bid advice are recommendations only\. "
            r"they never block generation of artifacts the user requested",
        )
        self.assertRegex(
            skill,
            r"the user is the sole decision-maker\..*?"
            r"never send messages, update crm",
        )

    def test_eval_ids_and_required_scenarios_are_present(self):
        payload = json.loads(EVALS.read_text(encoding="utf-8"))
        self.assertEqual(payload.get("skill_name"), "sales-process-harness")
        evals = payload.get("evals")
        self.assertIsInstance(evals, list)
        self.assertTrue(evals)

        ids = []
        for evaluation in evals:
            self.assertIsInstance(evaluation, dict)
            self.assertIsInstance(evaluation.get("id"), (str, int))
            self.assertNotIsInstance(evaluation["id"], bool)
            self.assertIsInstance(evaluation.get("prompt"), str)
            self.assertIsInstance(evaluation.get("expected_output"), str)
            ids.append(evaluation["id"])
        self.assertEqual(len(ids), len(set(ids)), "eval IDs must be unique")

        prompts = [evaluation["prompt"] for evaluation in evals]
        self.assertTrue(any(re.search(r"\bstalled opportunity\b", p, re.I) for p in prompts))
        self.assertTrue(any(re.search(r"\bRFP\b", p) for p in prompts))
        self.assertTrue(any(re.search(r"\bloss retrospective\b", p, re.I) for p in prompts))

        unknown_evals = [
            evaluation for evaluation in evals
            if re.search(r"all[- ]unknown[- ]evidence", evaluation["prompt"], re.I)
        ]
        self.assertEqual(len(unknown_evals), 1, "expected one all-unknown-evidence fixture")
        unknown_eval = unknown_evals[0]
        self.assertRegex(unknown_eval["prompt"], r"(?i)synthetic.*fictional")
        self.assertRegex(
            unknown_eval["prompt"],
            r"(?i)six other dimensions, so mark those six dimensions Unknown",
        )
        self.assertRegex(
            unknown_eval["prompt"],
            r"(?i)commercial viability Not assessed[—-]approved economics not supplied",
        )
        self.assertRegex(unknown_eval["expected_output"], r"(?i)score N/A")
        self.assertIn("0%", unknown_eval["expected_output"])
        self.assertRegex(
            unknown_eval["expected_output"],
            r"(?i)six other dimensions Unknown and commercial viability Not assessed",
        )
        self.assertRegex(
            unknown_eval["expected_output"],
            r"(?i)produces the requested scorecard, (?:focused )?questions, and "
            r"(?:compact )?artifact index",
        )

    def test_eval_expected_outputs_cover_required_behavior(self):
        payload = json.loads(EVALS.read_text(encoding="utf-8"))
        evaluations = {evaluation["id"]: evaluation for evaluation in payload["evals"]}

        stalled_output = normalized(evaluations[1]["expected_output"]).lower()
        self.assertRegex(stalled_output, r"poor (?:fit|score) or no[- ]bid")
        self.assertRegex(
            stalled_output,
            r"produce(?:s|d)? every requested artifact.*"
            r"(?:stall diagnosis|current-state).*scorecard.*questions.*artifact index",
        )

        rfp_output = normalized(evaluations[2]["expected_output"]).lower()
        self.assertRegex(rfp_output, r"no unsupported capability claims")
        self.assertRegex(
            rfp_output,
            r"no (?:invented or unsupported|invented|unsupported) pricing",
        )

        loss_output = normalized(evaluations[3]["expected_output"]).lower()
        self.assertRegex(loss_output, r"(?:customer|buyer)[- ]stated reason")
        self.assertRegex(loss_output, r"internal (?:architecture )?hypothesis")
        self.assertRegex(loss_output, r"not (?:a )?customer[- ]stated fact")

    def test_mixed_evidence_eval_arithmetic_matches_the_scorecard_formula(self):
        payload = json.loads(EVALS.read_text(encoding="utf-8"))
        mixed_evals = [
            evaluation for evaluation in payload["evals"]
            if re.search(r"mixed[- ]known[- /]unknown", evaluation["prompt"], re.I)
        ]
        self.assertEqual(len(mixed_evals), 1, "expected one mixed-known/unknown fixture")
        mixed_eval = mixed_evals[0]
        prompt = normalized(mixed_eval["prompt"]).lower()
        expected = normalized(mixed_eval["expected_output"]).lower()

        for supplied_rating in (
            "outcome/problem clarity 3/5 (20%)",
            "evidenced capability fit 4/5 (20%)",
            "solution/delivery feasibility 4/5 (15%)",
        ):
            self.assertIn(supplied_rating, prompt)
            self.assertIn(supplied_rating, expected)
        self.assertRegex(prompt, r"other four dimensions are unassessed")
        self.assertRegex(
            prompt,
            r"(?i)commercial viability Not assessed[—-]approved economics not supplied",
        )
        self.assertRegex(expected, r"other three dimensions are unknown")
        self.assertRegex(
            expected,
            r"(?i)commercial viability is Not assessed[—-]approved economics not supplied",
        )
        self.assertRegex(expected, r"assessed[- ]weight denominator (?:is )?55%")
        self.assertRegex(expected, r"weighted evidence coverage (?:is )?55%")
        self.assertRegex(expected, r"weighted score is .*?3\.6/5")
        self.assertIn(
            "(20×3 + 20×4 + 15×4)/55 = 200/55 = 3.6/5",
            expected,
        )
        self.assertRegex(expected, r"200/55\s*=\s*3\.6")
        self.assertRegex(expected, r"55/100\s*=\s*55%")

        weights_and_ratings = ((20, 3), (20, 4), (15, 4))
        assessed_weight = sum(weight for weight, _ in weights_and_ratings)
        weighted_sum = sum(weight * rating for weight, rating in weights_and_ratings)
        self.assertEqual(assessed_weight, 55)
        self.assertEqual(round(weighted_sum / assessed_weight, 1), 3.6)
        self.assertAlmostEqual(assessed_weight / 100 * 100, 55)

        scorecard = normalized(SCORECARD.read_text(encoding="utf-8"))
        self.assertRegex(
            scorecard,
            r"weighted score = sum\(weight_i × rating_i for i in A\)"
            r"\s*/\s*sum\(weight_i for i in A\)",
        )
        self.assertRegex(
            scorecard,
            r"weighted evidence coverage = sum\(weight_i for i in A\)"
            r"\s*/\s*100 × 100%",
        )

    def test_eval_mirrors_are_byte_identical(self):
        reference = EVAL_MIRRORS[0].read_bytes()
        for mirror in EVAL_MIRRORS[1:]:
            with self.subTest(mirror=mirror.relative_to(ROOT)):
                self.assertEqual(mirror.read_bytes(), reference)


if __name__ == "__main__":
    unittest.main()
