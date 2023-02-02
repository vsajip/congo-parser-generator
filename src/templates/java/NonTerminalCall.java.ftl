/* Generated by: ${generated_by}. ${filename}${grammar.copyrightBlurb} */
package ${grammar.parserPackage};

[#var BaseTokenType = grammar.treeBuildingEnabled?string("? extends Node.NodeType", "TokenType")]

import java.io.PrintStream;
import java.util.Set;

public class NonTerminalCall {
    final TokenSource lexer;
    final String sourceFile;
    final String productionName;
    final String parserClassName;
    final int line, column;
    final Set<${BaseTokenType}> followSet;

    NonTerminalCall(String parserClassName, TokenSource lexer, String sourceFile, String productionName, int line, int column, Set<${BaseTokenType}> followSet) {
        this.parserClassName = parserClassName;
        this.lexer = lexer;
        this.sourceFile = sourceFile;
        this.productionName = productionName;
        this.line = line;
        this.column = column;
        this.followSet = followSet;
    }

    final TokenSource getTokenSource() {
        return lexer;
    }

    StackTraceElement createStackTraceElement() {
        return new StackTraceElement("${grammar.parserClassName}", productionName, sourceFile, line);
    }

    void dump(PrintStream ps) {
         ps.println(productionName + ":" + line + ":" + column);
    }
}
