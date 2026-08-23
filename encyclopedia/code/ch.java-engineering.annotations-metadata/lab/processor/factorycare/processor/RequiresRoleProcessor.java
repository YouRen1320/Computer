package factorycare.processor;

import factorycare.metadata.CompileReport;
import factorycare.metadata.RequiresRole;
import java.io.IOException;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.annotation.processing.SupportedAnnotationTypes;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.TypeElement;
import javax.tools.Diagnostic;
import javax.tools.JavaFileObject;

@SupportedAnnotationTypes({
        "factorycare.metadata.ClassAudit",
        "factorycare.metadata.CompileReport",
        "factorycare.metadata.RequiresRole",
        "factorycare.metadata.RequiresRoles"
})
public final class RequiresRoleProcessor extends AbstractProcessor {
    private boolean generated;

    @Override
    public SourceVersion getSupportedSourceVersion() {
        return SourceVersion.RELEASE_25;
    }

    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        if (generated || roundEnv.processingOver()) {
            return true;
        }

        List<String> entries = new ArrayList<>();
        boolean sourceSeen = false;
        for (Element root : roundEnv.getRootElements()) {
            if (!(root instanceof TypeElement type)) {
                continue;
            }
            CompileReport report = type.getAnnotation(CompileReport.class);
            if (report == null) {
                continue;
            }
            sourceSeen |= !report.value().isBlank();
            for (RequiresRole role : type.getAnnotationsByType(RequiresRole.class)) {
                if (!role.value().matches("[A-Z][A-Z0-9_]*")) {
                    processingEnv.getMessager().printMessage(
                            Diagnostic.Kind.ERROR,
                            "role must match [A-Z][A-Z0-9_]*",
                            type);
                    continue;
                }
                entries.add(type.getQualifiedName() + "#" + role.value() + "@" + role.scope());
            }
        }
        Collections.sort(entries);

        if (!entries.isEmpty()) {
            writeIndex(entries, sourceSeen);
            generated = true;
        }
        return true;
    }

    private void writeIndex(List<String> entries, boolean sourceSeen) {
        try {
            JavaFileObject file = processingEnv.getFiler()
                    .createSourceFile("factorycare.generated.RoleIndex");
            try (Writer writer = file.openWriter()) {
                writer.write("package factorycare.generated;\n\n");
                writer.write("import java.util.List;\n\n");
                writer.write("public final class RoleIndex {\n");
                writer.write("    private RoleIndex() {}\n");
                writer.write("    public static boolean sourceSeen() { return " + sourceSeen + "; }\n");
                writer.write("    public static List<String> entries() { return List.of(\n");
                for (int index = 0; index < entries.size(); index++) {
                    String suffix = index + 1 == entries.size() ? "" : ",";
                    writer.write("            \"" + entries.get(index) + "\"" + suffix + "\n");
                }
                writer.write("    ); }\n");
                writer.write("}\n");
            }
        } catch (IOException exception) {
            processingEnv.getMessager().printMessage(
                    Diagnostic.Kind.ERROR,
                    "cannot generate RoleIndex: " + exception.getMessage());
        }
    }
}
