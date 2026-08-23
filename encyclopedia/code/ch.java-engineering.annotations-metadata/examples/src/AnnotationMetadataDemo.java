import java.lang.annotation.ElementType;
import java.lang.annotation.Inherited;
import java.lang.annotation.Repeatable;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.Method;

public final class AnnotationMetadataDemo {
    enum Severity { LOW, MEDIUM, HIGH }

    @Retention(RetentionPolicy.RUNTIME)
    @Target({ElementType.TYPE, ElementType.METHOD})
    @Repeatable(RequiresRoles.class)
    @interface RequiresRole {
        String value();
        String scope() default "tenant";
        Severity severity() default Severity.MEDIUM;
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target({ElementType.TYPE, ElementType.METHOD})
    @interface RequiresRoles {
        RequiresRole[] value();
    }

    @Retention(RetentionPolicy.SOURCE)
    @Target(ElementType.TYPE)
    @interface SourceNote {
        String value();
    }

    @Retention(RetentionPolicy.CLASS)
    @Target(ElementType.TYPE)
    @interface ClassNote {
        String value();
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.TYPE)
    @interface RuntimeNote {
        String value();
    }

    @Inherited
    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.TYPE)
    @interface DomainFamily {
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.TYPE_USE)
    @interface TypeUseNote {
        String value();
    }

    @SourceNote("source-only")
    @ClassNote("class-file-only")
    @RuntimeNote("runtime-visible")
    static class DevicePolicy {
        @RequiresRole("ADMIN")
        @RequiresRole(value = "DISPATCHER", severity = Severity.HIGH)
        void dispatch() {
        }

        @TypeUseNote("device-id")
        String deviceId;
    }

    @DomainFamily
    static class BaseWorkOrder {
    }

    static final class UrgentWorkOrder extends BaseWorkOrder {
    }

    @DomainFamily
    interface Categorized {
    }

    static final class InterfaceOnlyWorkOrder implements Categorized {
    }

    private AnnotationMetadataDemo() {
    }

    public static void main(String[] args) throws Exception {
        Method dispatch = DevicePolicy.class.getDeclaredMethod("dispatch");
        RequiresRole[] roles = dispatch.getAnnotationsByType(RequiresRole.class);

        require(roles.length == 2, "repeatable role count");
        require("ADMIN".equals(roles[0].value()), "first role");
        require("tenant".equals(roles[0].scope()), "default scope");
        require(roles[0].severity() == Severity.MEDIUM, "default enum value");
        require(roles[1].severity() == Severity.HIGH, "explicit enum value");
        require(!DevicePolicy.class.isAnnotationPresent(SourceNote.class), "SOURCE must be absent at runtime");
        require(!DevicePolicy.class.isAnnotationPresent(ClassNote.class), "CLASS must be absent from reflection");
        require(DevicePolicy.class.isAnnotationPresent(RuntimeNote.class), "RUNTIME must be visible");
        require(UrgentWorkOrder.class.isAnnotationPresent(DomainFamily.class), "class query inherits from superclass");
        require(UrgentWorkOrder.class.getDeclaredAnnotation(DomainFamily.class) == null, "inherited is not directly present");
        require(!InterfaceOnlyWorkOrder.class.isAnnotationPresent(DomainFamily.class), "interfaces do not supply @Inherited");

        TypeUseNote typeUse = DevicePolicy.class.getDeclaredField("deviceId")
                .getAnnotatedType()
                .getAnnotation(TypeUseNote.class);
        require(typeUse != null && "device-id".equals(typeUse.value()), "type-use annotation");

        System.out.println("roles=ADMIN|DISPATCHER");
        System.out.println("default-scope=tenant default-severity=MEDIUM");
        System.out.println("visibility=SOURCE:false CLASS:false RUNTIME:true");
        System.out.println("inherited=superclass:true declared:false interface:false");
        System.out.println("type-use=device-id");
        System.out.println("EXAMPLE PASS");
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
