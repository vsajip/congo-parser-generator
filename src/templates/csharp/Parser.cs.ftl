[#ftl strict_vars=true]
// ReSharper disable InconsistentNaming
[#import "CommonUtils.inc.ftl" as CU]
[#var MULTIPLE_LEXICAL_STATE_HANDLING = (grammar.lexerData.numLexicalStates >1)]
[#var csPackage = grammar.utils.getPreprocessorSymbol('cs.package', grammar.parserPackage) ]
namespace ${csPackage} {
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Text;
    using static TokenType;
${grammar.utils.translateParserImports()}

    public class ParseException : Exception {
        public Parser Parser { get; private set; }
        public Token Token { get; private set; }
        public HashSet<TokenType> Expected { get; private set; }
        private IList<NonTerminalCall> callStack;

        public ParseException(Parser parser, HashSet<TokenType> expected) : this(parser, null, null, expected) {}

        public ParseException(Parser parser, string message, Token token = null, HashSet<TokenType> expected = null) : base(message) {
            Parser = parser;
            if (token == null) {
                token = parser.LastConsumedToken;
                if ((token != null) && (token.Next != null)) {
                    token = token.Next;
                }
            }
            Token = token;
            Expected = expected;
            callStack = new List<NonTerminalCall>(parser.ParsingStack);
        }
    }

[#if grammar.treeBuildingEnabled]
    internal class NodeScope : List<Node> {
        private readonly NodeScope _parentScope;
        private readonly Parser _parser;

        public bool IsRootScope { get { return _parentScope == null; } }

        public Node RootNode {
            get {
                var ns = this;
                while (ns._parentScope != null) {
                    ns = ns._parentScope;
                }
                return (ns.Count == 0) ? null : ns[0];
            }
        }

        public uint NestingLevel {
            get {
                uint result = 0;
                var parent = this;
                while (parent._parentScope != null) {
                    result++;
                    parent = parent._parentScope;
                }
                return result;
            }
        }

        public NodeScope(Parser parser) {
            _parser = parser;
            _parentScope = parser.CurrentNodeScope;
            parser.CurrentNodeScope = this;
        }

        internal Node Peek() {
            Node result = null;

            if (Count > 0) {
                result = this[^1];
            }
            else if (_parentScope != null) {
                result = _parentScope.Peek();
            }
            return result;
        }

        internal Node Pop() {
            Node result = null;

            if (Count > 0) {
                result = Utils.Pop(this);
            }
            else if (_parentScope != null) {
                result = _parentScope.Pop();
            }
            return result;
        }

        internal void Poke(Node n) {
            if (Count == 0) {
                if (_parentScope != null) {
                    _parentScope.Poke(n);
                }
            }
            else {
                this[Count - 1] = n;
            }
        }

        internal void Close() {
            Debug.Assert(_parentScope != null);
            _parentScope.AddRange(this);
            _parser.CurrentNodeScope = _parentScope;
        }

        internal NodeScope Clone() {
            throw new NotImplementedException("NodeScope.Clone not yet implemented");
        }
    }

[/#if]

    //
    // Class that represents entering a grammar production
    //
    internal class NonTerminalCall {
        public Parser Parser { get; private set; }
        public string SourceFile { get; private set; }
        public string ProductionName { get; private set; }
        public uint Line { get; private set; }
        public uint Column { get; private set; }
        public ISet<TokenType> FollowSet { get; private set; }

        internal NonTerminalCall(Parser parser, string fileName, string productionName, uint line, uint column) {
            Parser = parser;
            SourceFile = fileName;
            ProductionName = productionName;
            Line = line;
            Column = column;
            FollowSet = parser.OuterFollowSet;
        }
/*
        private (string productionName, string sourceFile, uint line) CreateStackTraceElement() {
            return (ProductionName, SourceFile, Line);
        }
 */
    }

    internal class ParseState {
        public Parser Parser { get; private set; }
        public Token LastConsumed { get; private set; }
        public IList<NonTerminalCall> ParsingStack { get; private set; }
[#if MULTIPLE_LEXICAL_STATE_HANDLING]
        public LexicalState LexicalState {get; private set; }
[/#if]
[#if grammar.treeBuildingEnabled]
        public NodeScope NodeScope { get; private set; }
[/#if]

        internal ParseState(Parser parser) {
            Parser = parser;
            LastConsumed = parser.LastConsumedToken;
            ParsingStack = new List<NonTerminalCall>(parser.ParsingStack);
[#if MULTIPLE_LEXICAL_STATE_HANDLING]
            LexicalState = parser.tokenSource.LexicalState;
[/#if]
[#if grammar.treeBuildingEnabled]
            NodeScope = parser.CurrentNodeScope.Clone();
[/#if]
        }
    }

[#if grammar.treeBuildingEnabled]
    //
    // AST nodes
    //
[#list grammar.utils.sortedNodeClassNames as node]
  [#if !injector.hasInjectedCode(node)]
    [#if grammar.utils.nodeIsInterface(node)]
    public interface ${node} : Node {}
    [#else]
    public class ${node} : BaseNode {
        public ${node}(Lexer tokenSource) : base(tokenSource) {}
    }
    [/#if]

  [#else]
${grammar.utils.translateInjectedClass(node)}

  [/#if]
[/#list]
[/#if]


    public class Parser[#if unwanted!false] : IObservable<LogInfo>[/#if] {

        private const uint UNLIMITED = (1U << 31) - 1;

        public string InputSource { get; private set; }
        public Token LastConsumedToken { get; private set; }
        private Token currentLookaheadToken;
        public bool ScanToEnd { get; private set; }
        internal ISet<TokenType> OuterFollowSet { get; private set; }
        internal IList<NonTerminalCall> ParsingStack { get; private set; } = new List<NonTerminalCall>();
        internal readonly Lexer tokenSource;
[#if grammar.treeBuildingEnabled]
        public bool BuildTree { get; set; } = ${CU.bool(grammar.treeBuildingDefault)};
        public bool TokensAreNodes { get; set; } = ${CU.bool(grammar.tokensAreNodes)};
        public bool UnparsedTokensAreNodes { get; set; } = ${CU.bool(grammar.unparsedTokensAreNodes)};
        internal NodeScope CurrentNodeScope { get; set; }
[/#if]
[#if grammar.faultTolerant]
        public bool DebugFaultTolerant { get; set; } =  = ${CU.bool(grammar.debugFaultTolerant)};
[/#if]
        private TokenType? _nextTokenType;
        private uint _remainingLookahead;
        private bool _hitFailure;
        private string _currentlyParsedProduction;
        private string _currentLookaheadProduction;
        private uint _lookaheadRoutineNesting;
        //private ISet<TokenType> _currentFollowSet;
        private readonly IList<NonTerminalCall> _lookaheadStack = new List<NonTerminalCall>();
        private readonly IList<ParseState> _parseStateStack = new List<ParseState>();
[#if grammar.faultTolerant]
        private bool _tolerantParsing = true;
        private bool _pendingRecovery = false;
        private readonly IList<Node> _parsingProblems = new List<Node>();
[/#if]

[#if unwanted!false]
        private readonly IList<IObserver<LogInfo>> observers = new List<IObserver<LogInfo>>();

        public IDisposable Subscribe(IObserver<LogInfo> observer)
        {
            if (!observers.Contains(observer)) {
                observers.Add(observer);
            }
            return new Unsubscriber<LogInfo>(observers, observer);
        }

        internal void Log(LogLevel level, string message, params object[] arguments) {
            var info = new LogInfo(level, message, arguments);
            foreach (var observer in observers) {
                observer.OnNext(info);
            }
        }

[/#if]
        public Parser(string inputSource) {
            InputSource = inputSource;
            tokenSource = new Lexer(inputSource);
[#if grammar.lexerUsesParser]
            tokenSource.Parser = this;
[/#if]
            LastConsumedToken = Lexer.DummyStartToken;
[#if grammar.treeBuildingEnabled]
            new NodeScope(this); // attaches NodeScope instance to Parser instance
[/#if]
${grammar.utils.translateParserInitializers()}
        }

[#if grammar.faultTolerant]
        public void AddParsingProblem(BaseNode problem) {
            _parsingProblems.Add(problem);
        }

        public bool IsTolerant {
            get { return _tolerantParsing; }
            set { _tolerantParsing = value; }
        }
[#else]
        public bool IsTolerant {
            get { return false; }
        }
[/#if]


        private void PushLastTokenBack() {
[#if grammar.treeBuildingEnabled]
            if (PeekNode().Equals(LastConsumedToken)) {
                PopNode();
            }
[/#if]
            LastConsumedToken = LastConsumedToken.PreviousToken;
        }

        private void StashParseState() {
            _parseStateStack.Add(new ParseState(this));
        }

        private ParseState PopParseState() {
            return _parseStateStack.Pop();
        }

        private void RestoreStashedParseState() {
            var state = PopParseState();
[#if grammar.treeBuildingEnabled]
            CurrentNodeScope = state.NodeScope;
            ParsingStack = state.ParsingStack;
[/#if]
            if (state.LastConsumed != null) {
                // REVISIT
                LastConsumedToken = state.LastConsumed;
            }
[#if MULTIPLE_LEXICAL_STATE_HANDLING]
            tokenSource.Reset(LastConsumedToken, state.LexicalState);
[#else]
            tokenSource.Reset(LastConsumedToken);
[/#if]
        }

[#if grammar.treeBuildingEnabled]
        public bool IsTreeBuildingEnabled { get { return BuildTree; } }

   [#embed "TreeBuildingCode.inc.ftl"]
[#else]
        public bool IsTreeBuildingEnabled { get { return false; } }

[/#if]
        internal void PushOntoCallStack(string methodName, string fileName, uint line, uint column) {
            ParsingStack.Add(new NonTerminalCall(this, fileName, methodName, line, column));
        }

        internal void PopCallStack() {
            var ntc = ParsingStack.Pop();
            _currentlyParsedProduction = ntc.ProductionName;
            OuterFollowSet = ntc.FollowSet;
        }

        internal void RestoreCallStack(int prevSize) {
            while (ParsingStack.Count > prevSize) {
                PopCallStack();
            }
        }

        // If the next token is cached, it returns that
        // Otherwise, it goes to the lexer.
        private Token NextToken(Token tok) {
            Token result = tokenSource.GetNextToken(tok);
            while (result.IsUnparsed) {
[#list grammar.parserTokenHooks as methodName] 
                result = ${methodName}(result);
[/#list]
                result = tokenSource.GetNextToken(result);
            }
[#list grammar.parserTokenHooks as methodName] 
            result = ${methodName}(result);
[/#list]
            _nextTokenType = null;
            return result;
        }

        internal Token GetNextToken() {
            return GetToken(1);
        }

        /**
        * If we are in a lookahead, it looks ahead/behind from the currentLookaheadToken
        * Otherwise, it is the lastConsumedToken
        */
        public Token GetToken(int index) {
            var t = (currentLookaheadToken == null) ? LastConsumedToken : currentLookaheadToken;
            for (var i = 0; i < index; i++) {
                t = NextToken(t);
            }
            for (var i = 0; i > index; i--) {
                t = t.PreviousToken;
                if (t == null) break;
            }
            return t;
        }

        internal string TokenImage(int n) {
            return GetToken(n).Image;
        }

        internal bool CheckNextTokenImage(string img) {
            return TokenImage(1).Equals(img);
        }

        internal bool CheckNextTokenType(TokenType tt) {
            return GetToken(1).Type == tt;
        }

        internal TokenType NextTokenType {
            get {
                if (_nextTokenType == null) {
                    _nextTokenType = NextToken(LastConsumedToken).Type;
                }
                return _nextTokenType.Value;
            }
        }

        internal bool ActivateTokenTypes(TokenType type, params TokenType[] types) {
            var result = false;
            var att = tokenSource.ActiveTokenTypes;
            if (!att.Contains(type)) {
                result = true;
                att.Add(type);
            }
            foreach (var tt in types) {
                if (!att.Contains(tt)) {
                    result = true;
                    att.Add(tt);
                }
            }
            tokenSource.Reset(GetToken(0));
            _nextTokenType = null;
            return result;
        }

        internal bool DeactivateTokenTypes(TokenType type, params TokenType[] types) {
            var result = false;
            var att = tokenSource.ActiveTokenTypes;

            if (att.Contains(type)) {
                result = true;
                att.Remove(type);
            }
            foreach (var tt in types) {
                if (att.Contains(tt)) {
                    result = true;
                    att.Remove(tt);
                }
            }
            tokenSource.Reset(GetToken(0));
            _nextTokenType = null;
            return result;
        }

        private void Fail(string message) {
            if (currentLookaheadToken == null) {
                throw new ParseException(this, message);
            }
            _hitFailure = true;
        }

        /**
        *Are we in the production of the given name, either scanning ahead or parsing?
        */
        private bool IsInProduction(params string[] prodNames) {
            if (_currentlyParsedProduction != null) {
                foreach (var name in prodNames) {
                    if (_currentlyParsedProduction.Equals(name)) return true;
                }
            }
            if (_currentLookaheadProduction != null ) {
                foreach (var name in prodNames) {
                    if (_currentLookaheadProduction.Equals(name)) return true;
                }
            }
            var it = new BackwardIterator<NonTerminalCall>(ParsingStack, _lookaheadStack);
            while (it.HasNext()) {
                var ntc = it.Next();
                foreach (var name in prodNames) {
                    if (ntc.ProductionName.Equals(name)) {
                        return true;
                    }
                }
            }
            return false;
        }
[#import "ParserProductions.inc.ftl" as ParserCode]
[@ParserCode.Productions /]
[#import "LookaheadRoutines.inc.ftl" as LookaheadCode]
[@LookaheadCode.Generate/]

[#embed "ErrorHandling.inc.ftl"]


${grammar.utils.translateParserInjections(true)}
${grammar.utils.translateParserInjections(false)}

    }

/*

Still TODO:

[#list grammar.otherParserCodeDeclarations as decl]
        # Generated from code at ${decl.location}
        # TODO actual declaration
[/#list]
*/
}