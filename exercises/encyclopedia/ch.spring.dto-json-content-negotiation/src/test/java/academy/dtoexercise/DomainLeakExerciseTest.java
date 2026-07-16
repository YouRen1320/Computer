package academy.dtoexercise;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.Set;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class DomainLeakExerciseTest {
    private final JsonMapper mapper = JsonMapper.builder().build();

    @Test
    void responseKeepsThePublishedPublicFields() {
        var node = mapper.valueToTree(LeakExercise.response());
        assertEquals(42, node.path("id").asInt());
        assertEquals("OPEN", node.path("status").asString());
    }

    @Test
    void responseContainsOnlyThePublicContractFields() {
        var node = mapper.valueToTree(LeakExercise.response());
        Set<String> actual = Set.copyOf(node.propertyNames());
        Set<String> expected = Set.of("id", "assetId", "description", "priority", "status");
        assertEquals(expected, actual,
                "EXPECTED_DOMAIN_FIELDS_HIDDEN: internalCost and assigneeToken must not cross the wire");
        assertFalse(node.has("internalCost"));
        assertFalse(node.has("assigneeToken"));
    }
}
