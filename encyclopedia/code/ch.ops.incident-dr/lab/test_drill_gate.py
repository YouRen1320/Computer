import unittest

from drill_gate import audit, load_packet


class DrillGateTest(unittest.TestCase):
    def test_complete_tabletop_packet_passes(self) -> None:
        self.assertEqual([], audit(load_packet()))

    def test_destructive_unauthorized_recovery_is_rejected(self) -> None:
        packet = load_packet()
        packet["recovery"] = dict(packet["recovery"], authorized_by="", overwrites_source=True)
        errors = audit(packet)
        self.assertTrue(any("authorization" in error for error in errors))
        self.assertTrue(any("overwrite" in error for error in errors))

    def test_vague_action_and_personal_blame_are_rejected(self) -> None:
        packet = load_packet()
        packet["corrective_actions"][0] = {"id": "CA-1", "acceptance": "加强监控"}
        packet["postmortem"]["blames_person"] = True
        errors = audit(packet)
        self.assertTrue(any("lacks owner" in error for error in errors))
        self.assertTrue(any("personal blame" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
