[#-- This template generates the various lookahead/predicate routines --]

#import "common_utils.inc.ctl" as CU

#var UNLIMITED = 2147483647
[#-- var MULTIPLE_LEXICAL_STATE_HANDLING = lexerData.numLexicalStates > 1 --]
[#var MULTIPLE_LEXICAL_STATE_HANDLING = false]


#macro Generate
    [@firstSetVars /]
  #if settings.faultTolerant
    [@followSetVars /]
  #endif
  #if grammar.choicePointExpansions?size != 0
    [@BuildLookaheads 4 /]
  #endif
#endmacro


#macro firstSetVars
    # ==================================================================
    # EnumSets that represent the various expansions' first set (i.e. the set of tokens with which the expansion can begin)
    # ==================================================================
  #list grammar.expansionsForFirstSet as expansion
          [@CU.firstSetVar expansion/]
  #endlist
#endmacro

[#--
[#macro finalSetVars]
    # ==================================================================
    # EnumSets that represent the various expansions' final set (i.e. the set of tokens with which the expansion can end)
    # ==================================================================
    [#list grammar.expansionsForFinalSet as expansion]
          [@finalSetVar expansion/]
    [/#list]
[/#macro]
--]

#macro followSetVars
    # ==================================================================
    # EnumSets that represent the various expansions' follow set (i.e. the set of tokens that can immediately follow this)
    # ==================================================================
  #list grammar.expansionsForFollowSet as expansion
          [@CU.followSetVar expansion/]
  #endlist
#endmacro

[#--
  scan_token tends to be a big source of time spent in the parser,
  so we try to optimize it into two versions if optimize_scan_token is
  true - one for one type and one for many.
 --]
#var optimize_scan_token = true

[#macro BuildLookaheads indent]
  #if !optimize_scan_token
    def scan_token(self, expected_type_or_types):
        is_set = isinstance(expected_type_or_types, (set, frozenset))
        peeked_token = self.next_token(self.current_lookahead_token)
        tt = peeked_token.type
        if not is_set:
            no_match = tt != expected_type_or_types
        else:
            no_match = tt not in expected_type_or_types
        if no_match:
            return False
        self.remaining_lookahead -= 1
        self.current_lookahead_token = peeked_token
        return True

  #else
    def scan_token_one(self, expected_type):
        peeked_token = self.next_token(self.current_lookahead_token)
        if not self.type_matches(expected_type, peeked_token):
            return False
        self.remaining_lookahead -= 1
        self.current_lookahead_token = peeked_token
        return True

    def scan_token_many(self, expected_types):
        peeked_token = self.next_token(self.current_lookahead_token)
        if not self.has_match(expected_types, peeked_token):
            return False
        self.remaining_lookahead -= 1
        self.current_lookahead_token = peeked_token
        return True

    pass

#endif

# explicitdedent:on

#if lexerData.hasContextualTokens

    def IsContextualToken(self, type) :
      return (
         #list lexerData.contextualTokens as ctok
           type == TokenType.${ctok.label}
            ${ctok_has_next ?: "or"}
         #endlist
      )
    <-

    def IsIgnoreCase(self, type) :
        #if !lexerData.literalsThatDifferInCaseFromDefault
           return ${settings.ignoreCase ?: "True":"False"};
        #else
        return ${settings.ignoreCase ?: " not "} (
            #list lexerData.literalsThatDifferInCaseFromDefault as literal
                type == TokenType.${literal.label}
                ${literal_has_next ?: " or "}
            #endlist
        );
        #endif
    <-

    def GetLiteralString(self, type) :
        #list lexerData.regularExpressions as regexp
           ${regexp_index==0 ?: " if " : " elif "} (type == TokenType.${regexp.label}) :
               #if regexp.literalString??
                  return "${regexp.literalString?j_string}"
               #else
                  return None
               #endif
           <-
        #endlist
        return None
    <-

    def type_matches(self, type, tok) :
      if tok.type == type :
         return True;
      <-
      if (self.IsContextualToken(type)) :
         if self.IsIgnoreCase(type) :
             return self.GetLiteralString(type).lower() == tok.__str__().lower()
         <-
         else :
             return self.GetLiteralString(type) == tok.__str__()
         <-
      <-
      return False;
    <-

    def has_match(self, types, tok) :
      if tok.type in types :
         return True
      <-
      for tt in types :
         if self.IsContextualToken(tt) :
            if self.type_matches(tt, tok) :
               return True
            <-
         <-
      <-
      return False
    <-

#else
    def type_matches(self, type, tok) :
      return tok.type == type
    <-

    def has_match(self, types, tok) :
       return tok.type in types
    <-
#endif
# explicitdedent:restore


# ====================================
# Lookahead Routines
# ====================================
   [#list grammar.choicePointExpansions as expansion]
      [#if expansion.parent.class.simpleName != "BNFProduction"]
${BuildScanRoutine(expansion, indent)}
      [/#if]
   [/#list]
   [#list grammar.assertionExpansions as expansion]
${BuildAssertionRoutine(expansion, indent)}
   [/#list]   [#list grammar.expansionsNeedingPredicate as expansion]
${BuildPredicateRoutine(expansion)}
   [/#list]
   [#list grammar.allLookaheads as lookahead]
      [#if lookahead.nestedExpansion??]
${BuildLookaheadRoutine(lookahead, indent)}
     [/#if]
   [/#list]
   [#list grammar.allLookBehinds as lookBehind]
${BuildLookBehindRoutine(lookBehind, indent)}
   [/#list]
   [#list grammar.parserProductions as production]
${BuildProductionLookaheadMethod(production, indent)}
   [/#list]
[/#macro]

[#macro BuildPredicateRoutine expansion indent]
  [#var lookaheadAmount = expansion.lookaheadAmount]
  [#if lookaheadAmount = 2147483647][#set lookaheadAmount = "UNLIMITED"][/#if]
    # BuildPredicateRoutine: expansion at ${expansion.location}
    def ${expansion.predicateMethodName}(self):
        self.remaining_lookahead = ${lookaheadAmount}
        self.current_lookahead_token = self.last_consumed_token
        scan_to_end = False
        try:
${BuildPredicateCode(expansion, 12)}
      [#if !expansion.hasSeparateSyntacticLookahead && expansion.lookaheadAmount != 0]
${BuildScanCode(expansion, 12)}
      [/#if]
            return True
        finally:
            self.lookahead_routine_nesting = 0
            self.current_lookahead_token = None
            self.hit_failure = False
[/#macro]

[#macro BuildScanRoutine expansion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > BuildScanRoutine ${indent} --]
#if !expansion.singleTokenLookahead || expansion.requiresPredicateMethod
${is}# scanahead routine for expansion at:
${is}# ${expansion.location}
${is}# BuildScanRoutine macro
${is}def ${expansion.scanRoutineName}(self, scan_to_end):
${is}    # import pdb; pdb.set_trace()
  #if expansion.hasScanLimit
${is}    prev_passed_predicate_threshold = self.passed_predicate_threshold
${is}    self.passed_predicate_threshold = -1
  #else
${is}    reached_scan_code = False
${is}    passed_predicate_threshold = self.remaining_lookahead - ${expansion.lookaheadAmount}
  /#if
${is}    try:
${is}        self.lookahead_routine_nesting += 1
${BuildPredicateCode(expansion, indent + 8)}
  #if !expansion.hasScanLimit
${is}        reached_scan_code = True
  /#if
${BuildScanCode(expansion, indent + 8)}
${is}    finally:
${is}        self.lookahead_routine_nesting -= 1
  #if expansion.hasScanLimit
${is}        if self.remaining_lookahead <= self.passed_predicate_threshold:
${is}            self.passed_predicate = True
${is}            self.passed_predicate_threshold = prev_passed_predicate_threshold
  #else
${is}        if reached_scan_code and self.remaining_lookahead <= passed_predicate_threshold:
${is}            self.passed_predicate = True
  /#if
${is}    self.passed_predicate = False
${is}    return True
/#if
[#-- ${is}# DBG < BuildScanRoutine ${indent} --]
[/#macro]

[#macro BuildAssertionRoutine expansion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > BuildAssertionRoutine ${indent} --]
${is}# scanahead routine for assertion at:
${is}# ${expansion.parent.location}
${is}# BuildAssertionRoutine macro
${is}def ${expansion.scanRoutineName}(self):
${is}    # import pdb; pdb.set_trace()
  [#var storeCurrentLookaheadVar = CU.newVarName("currentLookahead")
        storeRemainingLookahead = CU.newVarName("remainingLookahead")]
  [#set newVarIndex = 0 in CU]
${is}    ${storeRemainingLookahead} = self.remaining_lookahead
${is}    self.remaining_lookahead = UNLIMITED
${is}    ${storeCurrentLookaheadVar} = self.current_lookahead_token
${is}    prev_hit_failure = self.hit_failure
${is}    if self.current_lookahead_token is None:
${is}        self.current_lookahead_token = self.last_consumed_token
${is}    try:
${is}        self.lookahead_routine_nesting += 1
${BuildScanCode(expansion, indent + 8)}
${is}        return True
${is}    finally:
${is}        self.lookahead_routine_nesting -= 1
${is}        self.current_lookahead_token = ${storeCurrentLookaheadVar}
${is}        self.remaining_lookahead = ${storeRemainingLookahead}
${is}        self.hit_failure = prev_hit_failure
[#-- ${is}# DBG < BuildAssertionRoutine ${indent} --]
[/#macro]

[#-- Build the code for checking semantic lookahead, lookbehind, and/or syntactic lookahead --]
#macro BuildPredicateCode expansion indent
#var is = ""?right_pad(indent)
[#-- ${is}# DBG > BuildPredicateCode ${indent} --]
#if expansion.hasSemanticLookahead && (expansion.lookahead.semanticLookaheadNested || expansion.containingProduction.onlyForLookahead)
${is}if not (${globals::translateExpression(expansion.semanticLookahead)}):
${is}    return False
/#if
#if expansion.hasLookBehind
${is}if [#if !expansion.lookBehind.negated]not [/#if]self.${expansion.lookBehind.routineName}():
${is}    return False
/#if
#if expansion.hasSeparateSyntacticLookahead
${is}if self.remaining_lookahead <= 0:
${is}    self.passed_predicate = True
${is}    return not self.hit_failure
${is}if [#if !expansion.lookahead.negated]not [/#if]self.${expansion.lookaheadExpansion.scanRoutineName}(True):
${is}    return False
/#if
#if expansion.lookaheadAmount == 0
${is}self.passed_predicate = True
/#if
[#-- ${is}# DBG < BuildPredicateCode ${indent} --]
/#macro


[#--
   Generates the routine for an explicit lookahead
   that is used in a nested lookahead.
 --]
[#macro BuildLookaheadRoutine lookahead indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > BuildLookaheadRoutine ${indent} --]
[#if lookahead.nestedExpansion??]
${is}# lookahead routine for lookahead at:
${is}# ${lookahead.location}
${is}def ${lookahead.nestedExpansion.scanRoutineName}(self, scan_to_end):
${is}    prev_remaining_lookahead = self.remaining_lookahead
${is}    prev_hit_failure = self.hit_failure
${is}    prev_scanahead_token = self.current_lookahead_token
${is}    try:
${is}        self.lookahead_routine_nesting += 1
${BuildScanCode(lookahead.nestedExpansion, indent + 8)}
${is}        return not self.hit_failure
${is}    finally:
${is}        self.lookahead_routine_nesting -= 1
${is}        self.current_lookahead_token = prev_scanahead_token
${is}        self.remaining_lookahead = prev_remaining_lookahead
${is}        self.hit_failure = prev_hit_failure
[/#if]
[#-- ${is}# DBG < BuildLookaheadRoutine ${indent} --]
[/#macro]

[#macro BuildLookBehindRoutine lookBehind indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > BuildLookBehindRoutine ${indent} --]
${is}# Look behind
${is}def ${lookBehind.routineName}(self):
${is}    stack_iterator = self.${lookBehind.backward?string("stack_iterator_backward", "stack_iterator_forward")}()
[#list lookBehind.path as element]
  [#var elementNegated = (element[0] == "~")]
  [#if elementNegated][#set element = element?substring(1)][/#if]
  [#if element = "."]
${is}    if not stack_iterator.has_next:
${is}        return False
${is}    stack_iterator.next
  [#elseif element = "..."]
    [#if element_index = lookBehind.path?size - 1]
      [#if lookBehind.hasEndingSlash]
${is}    return not stack_iterator.has_next
      [#else]
${is}    return True
      [/#if]
    [#else]
      [#var nextElement = lookBehind.path[element_index + 1]]
      [#var nextElementNegated = (nextElement[0]=="~")]
      [#if nextElementNegated][#set nextElement = nextElement?substring(1)][/#if]
${is}    while stack_iterator.has_next:
${is}        ntc = stack_iterator.next
      [#var equalityOp = nextElementNegated?string("!=", "==")]
${is}        if ntc.production_name ${equalityOp} "${nextElement}":
${is}            stack_iterator.previous
${is}            break
${is}        if not stack_iterator.has_next:
${is}            return False
    [/#if]
  [#else]
${is}    if not stack_iterator.has_next:
${is}        return False
${is}    ntc = stack_iterator.next
     [#var equalityOp = elementNegated?string("==", "!=")]
${is}    if ntc.production_name ${equalityOp} "${element}":
${is}        return False
  [/#if]
[/#list]
[#if lookBehind.hasEndingSlash]
${is}    return not stack_iterator.has_next
[#else]
${is}    return True
[/#if]
[#-- ${is}# DBG < BuildLookBehindRoutine ${indent} --]
[/#macro]

[#macro BuildProductionLookaheadMethod production indent]
[#var is = ""?right_pad(indent)]
[#--     # DBG > BuildProductionLookaheadMethod ${indent} --]
    # BuildProductionLookaheadMethod
    def ${production.lookaheadMethodName}(self, scan_to_end):
        # import pdb; pdb.set_trace()
${BuildScanCode(production.expansion, 8)}
        return True

[#--     # DBG < BuildProductionLookaheadMethod ${indent} --]
[/#macro]

[#--
   Macro to build the lookahead code for an expansion.
   This macro just delegates to the various sub-macros
   based on the Expansion's class name.
--]
[#macro BuildScanCode expansion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > BuildScanCode ${indent} ${expansion.simpleName} --]
  [#var classname = expansion.simpleName]
  [#if classname != "ExpansionSequence" && classname != "ExpansionWithParentheses"]
${is}if self.hit_failure:
${is}    return False
${is}if self.remaining_lookahead <= 0:
${is}    return True
${is}# Lookahead Code for ${classname} specified at ${expansion.location}
  [/#if]
  [@CU.HandleLexicalStateChange expansion, true, indent; indent]
  [#--
${is}# Building scan code for: ${classname}
${is}# at: ${expansion.location}
  --]
   [#if classname = "ExpansionWithParentheses"]
      [@BuildScanCode expansion.nestedExpansion, indent /]
   [#elseif expansion.singleTokenLookahead]
${ScanSingleToken(expansion, indent)}
   [#elseif classname = "Assertion" && expansion.appliesInLookahead]
${ScanCodeAssertion(expansion, indent)}
   [#elseif classname = "Failure"]
${ScanCodeError(expansion, indent)}
   [#elseif classname = "UncacheTokens"]
${is}self.uncache_tokens()
   [#elseif classname = "ExpansionSequence"]
${ScanCodeSequence(expansion, indent)}
   [#elseif classname = "ZeroOrOne"]
${ScanCodeZeroOrOne(expansion, indent)}
   [#elseif classname = "ZeroOrMore"]
${ScanCodeZeroOrMore(expansion, indent)}
   [#elseif classname = "OneOrMore"]
${ScanCodeOneOrMore(expansion, indent)}
   [#elseif classname = "NonTerminal"]
      [@ScanCodeNonTerminal expansion, indent /]
   [#elseif classname = "TryBlock" || classname = "AttemptBlock"]
      [@BuildScanCode expansion.nestedExpansion, indent /]
   [#elseif classname = "ExpansionChoice"]
${ScanCodeChoice(expansion, indent)}
   [#elseif classname = "CodeBlock"]
      [#if expansion.appliesInLookahead || expansion.insideLookahead || expansion.containingProduction.onlyForLookahead]
${globals::translateCodeBlock(expansion, indent)}
      [/#if]
   [/#if]
  [/@CU.HandleLexicalStateChange]
[#-- ${is}# DBG < BuildScanCode ${indent} ${expansion.simpleName} --]
[/#macro]

[#--
   Generates the lookahead code for an ExpansionSequence.
   In legacy JavaCC there was some quite complicated logic so as
   not to generate unnecessary code. They actually had a longstanding bug
   there, which was the topic of this blog post: https://congocc.com/2020/10/28/a-bugs-life/
   I very much doubt that this kind of space optimization is worth
   the candle nowadays and it just really complicated the code. Also, the ability
   to scan to the end of an expansion strike me as quite useful in general,
   particularly for fault-tolerant.
--]
#macro ScanCodeSequence sequence indent
#var is = ""?right_pad(indent)
[#-- ${is}# DBG > ScanCodeSequence ${indent} --]
#list sequence.units as sub
       [@BuildScanCode sub, indent /]
  #if sub.scanLimit
${is}if not scan_to_end and (len(self.lookahead_stack) <= 1):
${is}    if self.lookahead_routine_nesting == 0:
${is}        self.remaining_lookahead = ${sub.scanLimitPlus}
${is}    elif len(self.lookahead_stack) == 1:
${is}        self.passed_predicate_threshold = self.remaining_lookahead[#if sub.scanLimitPlus > 0] - ${sub.scanLimitPlus}[/#if]
  /#if
/#list
[#-- ${is}# DBG < ScanCodeSequence ${indent} --]
/#macro

[#--
  Generates the lookahead code for a non-terminal.
  It (trivially) just delegates to the code for
  checking the production's nested expansion
--]
[#macro ScanCodeNonTerminal nt indent]
[#var is = ""?right_pad(indent)]
${is}# NonTerminal ${nt.name} at ${nt.location}
${is}self.push_onto_lookahead_stack('${nt.containingProduction.name}', '${nt.inputSource?j_string}', ${nt.beginLine}, ${nt.beginColumn})
${is}self.current_lookahead_production = '${nt.production.name}'
${is}try:
${is}    if not self.${nt.production.lookaheadMethodName}(${CU.bool(nt.scanToEnd)}):
${is}        return False
${is}finally:
${is}    self.pop_lookahead_stack()
[/#macro]

[#macro ScanSingleToken expansion indent]
[#var is = ""?right_pad(indent)]
[#var firstSet = expansion.firstSet.tokenNames]
[#-- ${is}# DBG > ScanSingleToken ${indent} --]
[#if firstSet?size = 1]
[#if optimize_scan_token]
${is}if not self.scan_token_one(${firstSet[0]}):
[#else]
${is}if not self.scan_token(${firstSet[0]}):
[/#if]
${is}    return False
[#else]
[#if optimize_scan_token]
${is}if not self.scan_token_many(self.${expansion.firstSetVarName}):
[#else]
${is}if not self.scan_token(self.${expansion.firstSetVarName}):
[/#if]
${is}    return False
[/#if]
[#-- ${is}# DBG < ScanSingleToken ${indent} --]
[/#macro]

[#macro ScanCodeAssertion assertion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > ScanCodeAssertion ${indent} --]
#if assertion.assertionExpression??
${is}if not (${globals::translateExpression(assertion.assertionExpression)}):
${is}    self.hit_failure = True
${is}    return False
#endif
[#if assertion.expansion??]
${is}if [#if !assertion.expansionNegated]not [/#if]self.${assertion.expansion.scanRoutineName}():
${is}    self.hit_failure = True
${is}    return False
[/#if]
[#-- ${is}# DBG < ScanCodeAssertion ${indent} --]
[/#macro]

[#macro ScanCodeError expansion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > ScanCodeError ${indent} --]
${is}self.hit_failure = True
${is}return False
[#-- ${is}# DBG < ScanCodeError ${indent} --]
[/#macro]

#macro ScanCodeChoice choice indent
#var is = ""?right_pad(indent)
[#-- ${is}# DBG > ScanCodeChoice ${indent} --]
${is}${CU.newVarName("token")} = self.current_lookahead_token
${is}remaining_lookahead${CU.newVarIndex} = self.remaining_lookahead
${is}hit_failure${CU.newVarIndex} = self.hit_failure
${is}passed_predicate${CU.newVarIndex} = self.passed_predicate
${is}try:
#list choice.choices as subseq
${is}    self.passed_predicate = False
${is}    if not (${CheckExpansion(subseq)}):
${is}        self.current_lookahead_token = token${CU.newVarIndex}
${is}        self.remaining_lookahead = remaining_lookahead${CU.newVarIndex}
${is}        self.hit_failure = hit_failure${CU.newVarIndex}
  #if !subseq_has_next
${is}        return False
  #else
${is}        if self.passed_predicate and not self.legacy_glitchy_lookahead:
${is}            return False
  /#if
[#-- bump up the indentation, as the items in the list are recursive
     levels
--]
  #set is = is + "    "
/#list
[#list choice.choices as unused][#set is = is[4..]][/#list]
${is}finally:
${is}    self.passed_predicate = passed_predicate${CU.newVarIndex}
[#-- ${is}# DBG < ScanCodeChoice ${indent} --]
/#macro

#macro ScanCodeZeroOrOne zoo indent
#var is = ""?right_pad(indent)
[#-- ${is}# DBG > ScanCodeZeroOrOne ${indent} --]
${is}${CU.newVarName("token")} = self.current_lookahead_token
${is}passed_predicate${CU.newVarIndex} = self.passed_predicate
${is}self.passed_predicate = False
${is}try:
${is}    if not (${CheckExpansion(zoo.nestedExpansion)}):
${is}        if self.passed_predicate and not self.legacy_glitchy_lookahead:
${is}            return False
${is}        self.current_lookahead_token = token${CU.newVarIndex}
${is}        self.hit_failure = False
${is}finally:
${is}    self.passed_predicate = passed_predicate${CU.newVarIndex}
[#-- ${is}# DBG < ScanCodeZeroOrOne ${indent} --]
/#macro

[#--
  Generates lookahead code for a ZeroOrMore construct]
--]
#macro ScanCodeZeroOrMore zom indent
#var is = ""?right_pad(indent)
#var prevPassedPredicateVarName = CU.newVarName("passed_predicate")
#var prevTokenName = CU.newVarName("token")
${is}${prevPassedPredicateVarName} = self.passed_predicate
${is}try:
[#-- ${is}# DBG > ScanCodeZeroOrMore ${indent} --]
${is}    while self.remaining_lookahead > 0 and not self.hit_failure:
${is}        ${prevTokenName} = self.current_lookahead_token
${is}        self.passed_predicate = False
${is}        if not (${CheckExpansion(zom.nestedExpansion)}):
${is}            if self.passed_predicate and not self.legacy_glitchy_lookahead:
${is}                return False
${is}            self.current_lookahead_token = ${prevTokenName}
${is}            break
${is}finally:
${is}    self.passed_predicate = ${prevPassedPredicateVarName}
${is}self.hit_failure = False
[#-- ${is}# DBG < ScanCodeZeroOrMore ${indent} --]
/#macro

[#--
   Generates lookahead code for a OneOrMore construct
   It generates the code for checking a single occurrence
   and then the same code as a ZeroOrMore
--]
[#macro ScanCodeOneOrMore oom indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}# DBG > ScanCodeOneOrMore ${indent} --]
[#--${is}if not (${CheckExpansion(oom.nestedExpansion)}):
${is}    return False--]
[@BuildScanCode oom.nestedExpansion, indent /]
[@ScanCodeZeroOrMore oom, indent /]
[#-- ${is}# DBG < ScanCodeOneOrMore ${indent} --]
[/#macro]


#macro CheckExpansion expansion
#if expansion.singleTokenLookahead
  #if expansion.firstSet.tokenNames?size = 1
    #if optimize_scan_token
      self.scan_token_one(${expansion.firstSet.tokenNames[0]})[#t]
    #else
      self.scan_token(${expansion.firstSet.tokenNames[0]})[#t]
    #endif
  #else
    #if optimize_scan_token
      self.scan_token_many(self.${expansion.firstSetVarName})[#t]
    #else
      self.scan_token(self.${expansion.firstSetVarName})[#t]
    #endif
  #endif
#else
      self.${expansion.scanRoutineName}(False)[#t]
#endif
#endmacro


