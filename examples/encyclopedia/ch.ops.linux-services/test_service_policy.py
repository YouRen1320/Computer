import unittest

from service_policy import FilePolicy, Identity, may, selected_permission


class ServicePolicyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.policy = FilePolicy(owner="factorycare", group="factorycare", mode=0o750)

    def test_owner_group_and_other_select_different_digits(self) -> None:
        self.assertEqual(7, selected_permission(Identity("factorycare", frozenset()), self.policy))
        self.assertEqual(5, selected_permission(Identity("operator", frozenset({"factorycare"})), self.policy))
        self.assertEqual(0, selected_permission(Identity("guest", frozenset()), self.policy))

    def test_group_can_read_and_traverse_but_cannot_write(self) -> None:
        operator = Identity("operator", frozenset({"factorycare"}))
        self.assertTrue(may(operator, self.policy, "read"))
        self.assertTrue(may(operator, self.policy, "execute"))
        self.assertFalse(may(operator, self.policy, "write"))

    def test_unknown_operation_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown operation"):
            may(Identity("guest", frozenset()), self.policy, "delete")


if __name__ == "__main__":
    unittest.main()
