package org.congocc.output.java;

import java.io.IOException;
import java.io.Writer;
import java.io.StringWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

import org.congocc.Grammar;
import org.congocc.core.RegularExpression;
import org.congocc.parser.*;
import org.congocc.parser.tree.CompilationUnit;

import freemarker.template.*;
import freemarker.cache.*;
import freemarker.ext.beans.BeansWrapper;

public class FilesGenerator {

    private Configuration fmConfig;
    private final Grammar grammar;
    private final CodeInjector codeInjector;
    private final Set<String> tokenSubclassFileNames = new HashSet<>();
    private final HashMap<String, String> superClassLookup = new HashMap<>();
    private final String codeLang;

    void initializeTemplateEngine() throws IOException {
        fmConfig = new freemarker.template.Configuration();
        Path filename = grammar.getFilename().toAbsolutePath();
        Path dir = filename.getParent();
        //
        // The first two loaders are really for developers - templates
        // are looked for in the grammar's directory, and then in a
        // 'templates' subdirectory below that, which could, of course, be
        // a symlink to somewhere else.
        // We check for the 'templates' subdirectory existing, because otherwise
        // FreeMarker will raise an exception.
        //
        TemplateLoader templateLoader;
        String templateFolder = "/templates/".concat(codeLang);
        Path altDir = dir.resolve(templateFolder.substring(1));
        ArrayList<TemplateLoader> loaders = new ArrayList<>();
        loaders.add(new FileTemplateLoader(dir.toFile()));
        if (Files.exists(altDir)) {
            loaders.add(new FileTemplateLoader(altDir.toFile()));
        }
        loaders.add(new ClassTemplateLoader(this.getClass(), templateFolder));
        templateLoader = new MultiTemplateLoader(loaders.toArray(new TemplateLoader[0]));

        fmConfig.setTemplateLoader(templateLoader);
        fmConfig.setObjectWrapper(new BeansWrapper());
        fmConfig.setNumberFormat("computer");
        fmConfig.setArithmeticEngine(freemarker.core.ast.ArithmeticEngine.CONSERVATIVE_ENGINE);
        fmConfig.setStrictVariableDefinition(true);
    }

    public FilesGenerator(Grammar grammar, String codeLang, List<Node> codeInjections) {
        this.grammar = grammar;
        this.codeLang = codeLang;
        this.codeInjector = new CodeInjector(grammar,
                                             grammar.getParserPackage(), 
                                             grammar.getNodePackage(), 
                                             codeInjections);
    }

    public void generateAll() throws IOException, TemplateException { 
        if (grammar.getErrorCount() != 0) {
            throw new ParseException();
        }
        initializeTemplateEngine();
        switch (codeLang) {
            case "java":
                generateToken();
                generateLexer();
                generateOtherFiles();
                if (!grammar.getProductionTable().isEmpty()) {
                    generateParseException();
                    generateParser();
                }
                if (grammar.getFaultTolerant()) {
                    generateInvalidNode();
                    generateParsingProblem();
                }
                if (grammar.getTreeBuildingEnabled()) {
                    generateTreeBuildingFiles();
                }
                break;
            case "python": {
                // Hardcoded for now, could make configurable later
                String[] paths = new String[]{
                        "__init__.py",
                        "utils.py",
                        "tokens.py",
                        "lexer.py",
                        "parser.py"
                };
                Path outDir = grammar.getParserOutputDirectory();
                for (String p : paths) {
                    Path outputFile = outDir.resolve(p);
                    // Could check if regeneration is needed, but for now
                    // always (re)generate
                    generate(outputFile);
                }
                break;
            }
            case "csharp": {
                // Hardcoded for now, could make configurable later
                String[] paths = new String[]{
                        "Utils.cs",
                        "Tokens.cs",
                        "Lexer.cs",
                        "Parser.cs",
                        null  // filled in below
                };
                String csPackageName = grammar.getUtils().getPreprocessorSymbol("cs.package", grammar.getParserPackage());
                paths[paths.length - 1] = csPackageName + ".csproj";
                Path outDir = grammar.getParserOutputDirectory();
                for (String p : paths) {
                    Path outputFile = outDir.resolve(p);
                    // Could check if regeneration is needed, but for now
                    // always (re)generate
                    generate(outputFile);
                }
                break;
            }
            default:
                throw new UnsupportedOperationException(String.format("Code generation in '%s' is currently not supported.", codeLang));
        }
    }

    public void generate(Path outputFile) throws IOException, TemplateException {
        generate(null, outputFile);
    }

    private final Set<String> nonNodeNames = new HashSet<String>() {
        {
            add("ParseException.java");
            add("ParsingProblem.java");
            add("Token.java");
            add("InvalidToken.java");
            add("Node.java");
            add("InvalidNode.java");
            add("TokenSource.java");
            add("LexicalState.java");
            add("NonTerminalCall.java");
            add("TokenType.java");
        }
    };

    private String getTemplateName(String outputFilename) {
        String result = outputFilename + ".ftl";
        if (codeLang.equals("java")) {
            if (tokenSubclassFileNames.contains(outputFilename)) {
                result = "ASTToken.java.ftl";
            } else if (outputFilename.equals(grammar.getParserClassName() + ".java")) {
                result = "Parser.java.ftl";
            } else if (outputFilename.endsWith("Lexer.java")
                    || outputFilename.equals(grammar.getLexerClassName() + ".java")) {
                result = "Lexer.java.ftl";
            } else if (outputFilename.equals(grammar.getBaseNodeClassName() + ".java")) {
                result = "BaseNode.java.ftl";
            }
            else if (outputFilename.startsWith(grammar.getNodePrefix())) {
                if (!nonNodeNames.contains(outputFilename)) {
                    result = "ASTNode.java.ftl";
                }
            } 
        }
        else if (codeLang.equals("csharp")) {
            if (outputFilename.endsWith(".csproj")) {
                result = "project.csproj.ftl";
            }
        }
        return result;
    }

    public void generate(String nodeName, Path outputFile) throws IOException, TemplateException  {
        String currentFilename = outputFile.getFileName().toString();
        String templateName = getTemplateName(currentFilename);
        HashMap<String, Object> dataModel = new HashMap<>();
        dataModel.put("grammar", grammar);
        dataModel.put("filename", currentFilename);
        dataModel.put("isAbstract", grammar.nodeIsAbstract(nodeName));
        dataModel.put("isInterface", grammar.nodeIsInterface(nodeName));
        dataModel.put("generated_by", org.congocc.Main.PROG_NAME);
        String classname = currentFilename.substring(0, currentFilename.length() - 5);
        String superClassName = superClassLookup.get(classname);
        if (superClassName == null) superClassName = "Token";
        dataModel.put("superclass", superClassName);
        if (codeInjector.getExplicitlyDeclaredPackage(classname) != null) {
            dataModel.put("explicitPackageName", codeInjector.getExplicitlyDeclaredPackage(classname));
        }
        Writer out = new StringWriter();
        Template template = fmConfig.getTemplate(templateName);
        // Sometimes needed in templates for e.g. injector.hasInjectedCode(node)
        dataModel.put("injector", grammar.getInjector());
        template.process(dataModel, out);
        String code = out.toString();
        if (!grammar.isQuiet()) {
            System.out.println("Outputting: " + outputFile.normalize());
        }
        if (outputFile.getFileName().toString().endsWith(".java")) {
            outputJavaFile(code, outputFile);
        } else try (Writer outfile = Files.newBufferedWriter(outputFile)) {
            outfile.write(code);
        }
    }

    void outputJavaFile(String code, Path outputFile) throws IOException {
        Path dir = outputFile.getParent();
        if (Files.exists(dir)) {
            Files.createDirectories(dir);
        }
        CompilationUnit jcu;
        Writer out = Files.newBufferedWriter(outputFile);
        try {
            jcu = CongoCCParser.parseJavaFile(outputFile.getFileName().toString(), code);
        } catch (Exception e) {
            out.write(code);
            return;
        } finally {
            out.flush();
            out.close();
        }
        try (Writer output = Files.newBufferedWriter(outputFile)) {
            codeInjector.injectCode(jcu);
            JavaCodeUtils.removeWrongJDKElements(jcu, grammar.getJdkTarget());
            JavaCodeUtils.addGetterSetters(jcu);
            JavaCodeUtils.stripUnused(jcu);
            JavaFormatter formatter = new JavaFormatter();
            output.write(formatter.format(jcu));
        }
    }

    void generateOtherFiles() throws IOException, TemplateException {
        Path outputFile = grammar.getParserOutputDirectory().resolve("TokenType.java");
        generate(outputFile);
        outputFile = grammar.getParserOutputDirectory().resolve("LexicalState.java");
        generate(outputFile);
        if (grammar.getRootAPIPackage() == null) {
            outputFile = grammar.getParserOutputDirectory().resolve("TokenSource.java");
            generate(outputFile);
            outputFile = grammar.getParserOutputDirectory().resolve("NonTerminalCall.java");
            generate(outputFile);
        }
    }

    void generateParseException() throws IOException, TemplateException {
        Path outputFile = grammar.getParserOutputDirectory().resolve("ParseException.java");
        if (regenerate(outputFile)) {
            generate(outputFile);
        }
    }

    void generateParsingProblem() throws IOException, TemplateException {
        Path outputFile = grammar.getParserOutputDirectory().resolve("ParsingProblem.java");
        if (regenerate(outputFile)) {
            generate(outputFile);
        }
    }

    void generateInvalidNode() throws IOException, TemplateException {
        Path outputFile = grammar.getParserOutputDirectory().resolve("InvalidNode.java");
        if (regenerate(outputFile)) {
            generate(outputFile);
        }
    }

    void generateToken() throws IOException, TemplateException {
        Path outputFile = grammar.getParserOutputDirectory().resolve("Token.java");
        if (regenerate(outputFile)) {
            generate(outputFile);
        }
        outputFile = grammar.getParserOutputDirectory().resolve("InvalidToken.java");
        if (regenerate(outputFile)) {
            generate(outputFile);
        }
    }
    
    void generateLexer() throws IOException, TemplateException {
        String filename = grammar.getLexerClassName() + ".java";
        Path outputFile = grammar.getParserOutputDirectory().resolve(filename);
        generate(outputFile);
    }

    void generateParser() throws IOException, TemplateException {
        if (grammar.getErrorCount() !=0) {
        	throw new ParseException();
        }
        String filename = grammar.getParserClassName() + ".java";
        Path outputFile = grammar.getParserOutputDirectory().resolve(filename);
        generate(outputFile);
    }
    
    void generateNodeFile() throws IOException, TemplateException {
        Path outputFile = grammar.getParserOutputDirectory().resolve("Node.java");
        if (regenerate(outputFile)) {
            generate(outputFile);
        }
    }

    private boolean regenerate(Path file) throws IOException {
        if (!Files.exists(file)) {
        	return true;
        } 
        String ourName = file.getFileName().toString();
        String canonicalName = file.normalize().getFileName().toString();
       	if (canonicalName.equalsIgnoreCase(ourName) && !canonicalName.equals(ourName)) {
            String msg = "You cannot have two files that differ only in case, as in " 
       	                          + ourName + " and "+ canonicalName 
       	                          + "\nThis does work on a case-sensitive file system but fails on a case-insensitive one (i.e. Mac/Windows)"
       	                          + " \nYou will need to rename something in your grammar!";
            throw new IOException(msg);
        }
        String filename = file.getFileName().toString();
        // Changes here to allow different rules to be used for different
        // languages. At the moment there are no non-Java code injections
        String extension = codeLang.equals("java") ? ".java" : codeLang.equals("python") ? ".py" : ".cs";
        if (filename.endsWith(extension)) {
            String typename = filename.substring(0, filename.length()  - extension.length());
            if (codeInjector.hasInjectedCode(typename)) {
                return true;
            }
        }
        //
        // For now regenerate() isn't called for generating Python or C# files,
        // but I'll leave this here for the moment
        //
        return extension.equals(".py") || extension.equals(".cs");    // for now, always regenerate
    }

    void generateTreeBuildingFiles() throws IOException, TemplateException {
        if (grammar.getRootAPIPackage() == null) {
    	    generateNodeFile();
        }
        Map<String, Path> files = new LinkedHashMap<>();
        files.put(grammar.getBaseNodeClassName(), getOutputFile(grammar.getBaseNodeClassName()));

        for (RegularExpression re : grammar.getOrderedNamedTokens()) {
            if (re.isPrivate()) continue;
            String tokenClassName = re.getGeneratedClassName();
            Path outputFile = getOutputFile(tokenClassName);
            files.put(tokenClassName, outputFile);
            tokenSubclassFileNames.add(outputFile.getFileName().toString());
            String superClassName = re.getGeneratedSuperClassName();
            if (superClassName != null) {
                outputFile = getOutputFile(superClassName);
                files.put(superClassName, outputFile);
                tokenSubclassFileNames.add(outputFile.getFileName().toString());
                superClassLookup.put(tokenClassName, superClassName);
            }
        }
        for (Map.Entry<String, String> es : grammar.getExtraTokens().entrySet()) {
            String value = es.getValue();
            Path outputFile = getOutputFile(value);
            files.put(value, outputFile);
            tokenSubclassFileNames.add(outputFile.getFileName().toString());
        }
        for (String nodeName : grammar.getNodeNames()) {
            if (nodeName.indexOf('.')>0) continue;
            Path outputFile = getOutputFile(nodeName);
            if (tokenSubclassFileNames.contains(outputFile.getFileName().toString())) {
                String name = outputFile.getFileName().toString();
                name = name.substring(0, name.length() -5);
                grammar.addError("The name " + name + " is already used as a Token subclass.");
            }
            files.put(nodeName, outputFile);
        }
        for (Map.Entry<String, Path> entry : files.entrySet()) {
            if (regenerate(entry.getValue())) {
                generate(entry.getKey(), entry.getValue());
            }
        }
    }

    // only used for tree-building files (a bit kludgy)
    private Path getOutputFile(String nodeName) throws IOException {
        if (nodeName.equals(grammar.getBaseNodeClassName())) {
            return grammar.getBaseNodeInParserPackage() ? 
               grammar.getParserOutputDirectory().resolve(nodeName + ".java") :
               grammar.getNodeOutputDirectory().resolve(nodeName + ".java");
        }
        String className = grammar.getNodeClassName(nodeName);
        //KLUDGE
        if (nodeName.equals(grammar.getBaseNodeClassName())) {
            className = nodeName;
        }
        String explicitlyDeclaredPackage = codeInjector.getExplicitlyDeclaredPackage(className);
        if (explicitlyDeclaredPackage == null) {
            return grammar.getNodeOutputDirectory().resolve(className + ".java");
        }
        String sourceBase = grammar.getBaseSourceDirectory();
        if (sourceBase.equals("")) {
            return grammar.getNodeOutputDirectory().resolve(className + ".java");
        }
        Path result = Paths.get(sourceBase);
        result = result.resolve(explicitlyDeclaredPackage.replace('.', '/'));
        return result.resolve(className + ".java");
    }
}