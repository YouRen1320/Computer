public final class ModularMonolithChallenge {
    private static void require(boolean condition, String marker) {
        if (!condition) throw new IllegalStateException(marker);
    }

    public static void main(String[] args) {
        // TODO 1: expose only module API types, never another module's internal Repository.
        require(false, "INTERNAL_PACKAGE_EXPOSED");
        // TODO 2: keep the module dependency graph acyclic.
        require(false, "MODULE_CYCLE");
        // TODO 3: reject dependencies outside the declared allow-list.
        require(false, "UNDECLARED_DEPENDENCY");
        // TODO 4: give every mutable entity one owning module.
        require(false, "SHARED_MUTABLE_ENTITY");
        // TODO 5: keep the shared kernel technical and minimal.
        require(false, "COMMON_BUSINESS_SERVICE");
        // TODO 6: move derived reactions after the core transaction via an event.
        require(false, "DERIVED_FAILURE_ROLLS_BACK_CORE");
        // TODO 7: make workorders testable with only direct dependency ports.
        require(false, "MODULE_NOT_ISOLATABLE");
        // TODO 8: require team/data/scale/release/isolation evidence before splitting.
        require(false, "UNSUPPORTED_SPLIT_SIGNAL");
        System.out.println("challenge=PASS microservice_claim=false");
    }
}
