[#-- This template contains the core logic for generating the various parser routines. --]

[#var nodeNumbering = 0]
[#var NODE_USES_PARSER = settings.nodeUsesParser]
[#var NODE_PREFIX = grammar.nodePrefix]
[#var currentProduction]

[#macro Productions] 
 //=================================
 // Start of methods for BNF Productions
 //This code is generated by the ParserProductions.java.ftl template. 
 //=================================
  [#list grammar.parserProductions as production]
   [#set nodeNumbering = 0]
   [@CU.firstSetVar production.expansion/]
   [#if !production.onlyForLookahead]
    [#set currentProduction = production]
    [@ParserProduction production/]
   [/#if]
  [/#list]
  [#if settings.faultTolerant]
    [@BuildRecoverRoutines /]
  [/#if]
[/#macro]

[#macro ParserProduction production]
    [#set nodeNumbering = 0]
    [#set newVarIndex = 0 in CU] 
    ${production.leadingComments}
// ${production.location}
    final ${production.accessModifier}
    ${production.returnType}
    ${production.name}(${production.parameterList!}) 
   [#if settings.useCheckedException]    
    throws ParseException
    [#list (production.throwsList.types)! as throw], ${throw}[/#list] 
   [#elseif (production.throwsList.types)?has_content] 
     [#list production.throwsList.types as throw]
        [#if throw_index == 0]
           throws ${throw}
        [#else]
           , ${throw}
        [/#if]
     [/#list] 
   [/#if]
    
    {
     if (cancelled) throw new CancellationException();
     String prevProduction = currentlyParsedProduction;
     this.currentlyParsedProduction = "${production.name}";
     [#--${production.javaCode!}
       This is actually inserted further down because
       we want the prologue java code block to be able to refer to 
       CURRENT_NODE.
     --]
     [@BuildCode production.expansion /]
    }   
[/#macro]

[#macro BuildCode expansion]
  [#if expansion.simpleName != "ExpansionSequence" && expansion.simpleName != "ExpansionWithParentheses"]
  // Code for ${expansion.simpleName} specified at ${expansion.location}
  [/#if]
     [@CU.HandleLexicalStateChange expansion false]
         [#if settings.faultTolerant && expansion.requiresRecoverMethod && !expansion.possiblyEmpty]
         if (pendingRecovery) {
//            if (debugFaultTolerant) LOGGER.info("Re-synching to expansion at: ${expansion.location?j_string}");
            ${expansion.recoverMethodName}();
         }
         [/#if]
         [@TreeBuildingAndRecovery expansion]
           [@BuildExpansionCode expansion/]
         [/@TreeBuildingAndRecovery]
     [/@CU.HandleLexicalStateChange]
[/#macro]

[#macro TreeBuildingAndRecovery expansion]
   [#var production = expansion.containingProduction, 
         treeNodeBehavior,
         buildingTreeNode=false,
         nodeVarName,
         javaCodePrologue = "",
         parseExceptionVar = CU.newVarName("parseException"),
         callStackSizeVar = CU.newVarName("callStackSize"),
         canRecover = settings.faultTolerant && expansion.tolerantParsing && expansion.simpleName != "Terminal"
   ]
   [#set treeNodeBehavior = resolveTreeNodeBehavior(expansion)]
   [#if expansion.parent != production] 
      [#set production = null]
   [#else]
      [#set javaCodePrologue = production.javaCode!]
   [/#if]
   [#if treeNodeBehavior??]
      [#if settings.treeBuildingEnabled]
         [#set buildingTreeNode = true]
         [#set nodeVarName = nodeVar(production??)]
      [/#if]
   [/#if]
   [#if !buildingTreeNode && !canRecover]
      [#-- We need neither tree nodes nor recovery code; do the simple one. --]
      ${javaCodePrologue} 
      [#nested]
   [#else]
      [#-- We need tree nodes and/or recovery code. --]      
      [#if buildingTreeNode]
         [#-- Build the tree node (part 1). --]
         [@buildTreeNode production treeNodeBehavior nodeVarName /]
      [/#if]
      [#--  The prologue code can refer to CURRENT_NODE at this point. --]
      ${javaCodePrologue}
      ParseException ${parseExceptionVar} = null;
      int ${callStackSizeVar} = parsingStack.size();
      try {
      [#if settings.useCheckedException]
         if (false) throw new ParseException("Never happens!");
      [/#if]
         [#-- Here is the "nut". --]
         [#nested]
      } 
      catch (ParseException e) { 
         ${parseExceptionVar} = e;
      [#if !canRecover]
         [#if settings.faultTolerant]
         if (isParserTolerant()) this.pendingRecovery = true;
         [/#if]
         throw e;
      [#else]
         if (!isParserTolerant()) throw e;
         this.pendingRecovery = true;
         ${expansion.customErrorRecoveryBlock!}
         [#if !production?is_null && production.returnType != "void"]
            [#var rt = production.returnType]
            [#-- We need a return statement here or the code won't compile! --]
            [#if rt = "int" || rt="char" || rt=="byte" || rt="short" || rt="long" || rt="float"|| rt="double"]
         return 0;
            [#else]
         return null;
            [/#if]
         [/#if]
      [/#if]
      }
      finally {
         restoreCallStack(${callStackSizeVar});
      [#if buildingTreeNode]
         [#-- Build the tree node (part 2). --]
         [@buildTreeNodeEpilogue treeNodeBehavior nodeVarName parseExceptionVar /]
      [/#if]
         this.currentlyParsedProduction = prevProduction;
      }       
   [/#if]
[/#macro]

[#function resolveTreeNodeBehavior expansion]
   [#var treeNodeBehavior = expansion.treeNodeBehavior, production ]
   [#if expansion.parent.simpleName = "BNFProduction"]
      [#set production = expansion.parent]
   [/#if]
   [#if !treeNodeBehavior??] 
      [#if production?? && !settings.nodeDefaultVoid 
                        && !grammar.nodeIsInterface(production.name)
                        && !grammar.nodeIsAbstract(production.name)]
         [#if settings.smartNodeCreation]
            [#set treeNodeBehavior = {"nodeName" : production.name!"nemo", "condition" : "1", "gtNode" : true, "void" :false, "initialShorthand" : ">"}]
         [#else]
            [#set treeNodeBehavior = {"nodeName" : production.name!"nemo", "condition" : null, "gtNode" : false, "void" : false}]
         [/#if]
      [/#if]
   [/#if]
   [#if treeNodeBehavior?? && treeNodeBehavior.neverInstantiated?? && treeNodeBehavior.neverInstantiated]
      [#return null/]
   [/#if]
   [#return treeNodeBehavior]
[/#function]

[#macro buildTreeNode production treeNodeBehavior nodeVarName]
   ${globals.pushNodeVariableName(nodeVarName)!}
   [@createNode nodeClassName(treeNodeBehavior) nodeVarName /]
[/#macro]

[#macro buildTreeNodeEpilogue treeNodeBehavior nodeVarName parseExceptionVar]
   if (${nodeVarName}!=null) {
      if (${parseExceptionVar} == null) {
   [#if treeNodeBehavior?? && treeNodeBehavior.LHS??]
         if (closeNodeScope(${nodeVarName}, ${closeCondition(treeNodeBehavior)})) {
            ${treeNodeBehavior.LHS} = (${nodeClassName(treeNodeBehavior)}) peekNode();
         } else{
            ${treeNodeBehavior.LHS} = null;
         }
   [#else]
         closeNodeScope(${nodeVarName}, ${closeCondition(treeNodeBehavior)}); 
   [/#if]
   [#list grammar.closeNodeHooksByClass[nodeClassName(treeNodeBehavior)]! as hook]
         ${hook}(${nodeVarName});
   [/#list]
      } else {
   [#if settings.faultTolerant]
         closeNodeScope(${nodeVarName}, true);
         ${nodeVarName}.setDirty(true);
   [#else]
         clearNodeScope();
   [/#if]
      }
   }
   ${globals.popNodeVariableName()!}
[/#macro]

[#function nodeVar isProduction]
   [#var nodeVarName]
   [#if isProduction]
      [#set nodeVarName = "thisProduction"] [#-- [JB] maybe should be "CURRENT_PRODUCTION" or "THIS_PRODUCTION" to match "CURRENT_NODE"? --]
   [#else]
      [#set nodeNumbering = nodeNumbering +1]
      [#set nodeVarName = currentProduction.name + nodeNumbering] 
   [/#if]
   [#return nodeVarName/]
[/#function]

[#function closeCondition treeNodeBehavior]
   [#var cc = "true"]
   [#if treeNodeBehavior??]
      [#if treeNodeBehavior.condition?has_content]
         [#set cc = treeNodeBehavior.condition]
         [#if treeNodeBehavior.gtNode]
            [#set cc = "nodeArity() " + treeNodeBehavior.initialShorthand  + cc]
         [/#if]
      [/#if]
   [/#if]
   [#return cc/]
[/#function]

[#--  Boilerplate code to create the node variable --]
[#macro createNode nodeClass nodeVarName]
   ${nodeClass} 
   ${nodeVarName} = null;
   if (buildTree) {
     ${nodeVarName} = new ${nodeClass}();
    [#if settings.nodeUsesParser]
     ${nodeVarName}.setParser(this);
    [/#if]
        openNodeScope(${nodeVarName});
   }
[/#macro]

[#function nodeClassName treeNodeBehavior]
   [#if treeNodeBehavior?? && treeNodeBehavior.nodeName??] 
      [#return NODE_PREFIX + treeNodeBehavior.nodeName]
   [/#if]
   [#return NODE_PREFIX + currentProduction.name/]
[/#function]


[#macro BuildExpansionCode expansion]
    [#var classname=expansion.simpleName]
    [#var prevLexicalStateVar = CU.newVarName("previousLexicalState")]
    [#if classname = "ExpansionWithParentheses"]
       [@BuildExpansionCode expansion.nestedExpansion/]
    [#elseif classname = "CodeBlock"]
       ${expansion}
    [#elseif classname = "UncacheTokens"]
         uncacheTokens();
    [#elseif classname = "Failure"]
       [@BuildCodeFailure expansion/]
    [#elseif classname = "TokenTypeActivation"]
       [@BuildCodeTokenTypeActivation expansion/]
    [#elseif classname = "ExpansionSequence"]
       [@BuildCodeSequence expansion/]
    [#elseif classname = "NonTerminal"]
       [@BuildCodeNonTerminal expansion/]
    [#elseif classname = "Terminal"]
       [@BuildCodeTerminal expansion /]
    [#elseif classname = "TryBlock"]
       [@BuildCodeTryBlock expansion/]
    [#elseif classname = "AttemptBlock"]
       [@BuildCodeAttemptBlock expansion /]
    [#elseif classname = "ZeroOrOne"]
       [@BuildCodeZeroOrOne expansion/]
    [#elseif classname = "ZeroOrMore"]
       [@BuildCodeZeroOrMore expansion/]
    [#elseif classname = "OneOrMore"]
        [@BuildCodeOneOrMore expansion/]
    [#elseif classname = "ExpansionChoice"]
        [@BuildCodeChoice expansion/]
    [#elseif classname = "Assertion"]
        [@BuildAssertionCode expansion/]
    [/#if]
[/#macro]

[#macro BuildCodeFailure fail]
    [#if fail.code?is_null]
      [#if fail.exp??]
       fail("Failure: " + ${fail.exp}, getToken(1));
      [#else]
       fail("Failure", getToken(1));
      [/#if]
    [#else]
       ${fail.code}
    [/#if]
[/#macro]

[#macro BuildCodeTokenTypeActivation activation]
    [#if activation.deactivate]
       deactivateTokenTypes(
    [#else]
       activateTokenTypes(
    [/#if]
    [#list activation.tokenNames as name]
       ${name} [#if name_has_next],[/#if]
    [/#list]
       );
[/#macro]

[#macro BuildCodeSequence expansion]
       [#list expansion.units as subexp]
           [@BuildCode subexp/]
       [/#list]        
[/#macro]

[#macro BuildCodeTerminal terminal]
   [#var LHS = "", regexp=terminal.regexp]
   [#if terminal.lhs??]
      [#set LHS = terminal.lhs + "="]
   [/#if]
   [#if !settings.faultTolerant]
       ${LHS} consumeToken(${regexp.label});
   [#else]
       [#var tolerant = terminal.tolerantParsing?string("true", "false")]
       [#var followSetVarName = terminal.followSetVarName]
       [#if terminal.followSet.incomplete]
         [#set followSetVarName = "followSet" + CU.newID()]
         EnumSet<TokenType> ${followSetVarName} = null;
         if (outerFollowSet != null) {
            ${followSetVarName} = ${terminal.followSetVarName}.clone();
            ${followSetVarName}.addAll(outerFollowSet);
         }
       [/#if]
       ${LHS} consumeToken(${regexp.label}, ${tolerant}, ${followSetVarName});
   [/#if]
   [#if !terminal.childName?is_null && !globals.currentNodeVariableName?is_null]
    if (buildTree) {
        Node child = peekNode();
        String name = "${terminal.childName}";
    [#if terminal.multipleChildren]
        ${globals.currentNodeVariableName}.addToNamedChildList(name, child);
    [#else]
        ${globals.currentNodeVariableName}.setNamedChild(name, child);
    [/#if]
    }
   [/#if]
[/#macro]

[#macro BuildCodeTryBlock tryblock]
     try {
        [@BuildCode tryblock.nestedExpansion /]
     }
   [#list tryblock.catchBlocks as catchBlock]
     ${catchBlock}
   [/#list]
     ${tryblock.finallyBlock!}
[/#macro]

[#macro BuildCodeAttemptBlock attemptBlock]
   try {
      stashParseState();
      [@BuildCode attemptBlock.nestedExpansion /]
      popParseState();
   }
   catch (ParseException e) {
      restoreStashedParseState();
      [@BuildCode attemptBlock.recoveryExpansion /]
   }
[/#macro]

[#macro BuildCodeNonTerminal nonterminal]
   [#var production = nonterminal.production, LHS]
   pushOntoCallStack("${nonterminal.containingProduction.name}", "${nonterminal.inputSource?j_string}", ${nonterminal.beginLine}, ${nonterminal.beginColumn});
   [#if settings.faultTolerant]
      [#var followSet = nonterminal.followSet]
      [#if !followSet.incomplete]
         [#if !nonterminal.beforeLexicalStateSwitch]
            outerFollowSet = ${nonterminal.followSetVarName};
         [#else]
            outerFollowSet = null;
         [/#if]
      [#elseif !followSet.isEmpty()]
         if (outerFollowSet != null) {
            EnumSet<TokenType> newFollowSet = ${nonterminal.followSetVarName}.clone();
            newFollowSet.addAll(outerFollowSet);
            outerFollowSet = newFollowSet;
         }
      [/#if]
   [/#if]
   try {
   [#if nonterminal.LHS??]
      [#set LHS = nonterminal.LHS]
   [/#if]
   [#if LHS?? && production.returnType != "void"]
       ${LHS} = 
   [/#if]
      ${nonterminal.name}(${nonterminal.args!});
   [#if LHS?? && production.returnType = "void"]
      try {
         ${LHS} = (${production.nodeName}) peekNode();
      } catch (ClassCastException cce) {
         ${LHS} = null;
      }
   [/#if]
   [#if !nonterminal.childName?is_null]
        if (buildTree) {
            Node child = peekNode();
            String name = "${nonterminal.childName}";
    [#if nonterminal.multipleChildren]
            ${globals.currentNodeVariableName}.addToNamedChildList(name, child);
    [#else]
            ${globals.currentNodeVariableName}.setNamedChild(name, child);
    [/#if]
        }
   [/#if]
   } 
   finally {
       popCallStack();
   }
[/#macro]


[#macro BuildCodeZeroOrOne zoo]
    [#if zoo.nestedExpansion.class.simpleName = "ExpansionChoice"]
       [@BuildCode zoo.nestedExpansion /]
    [#else]
       if (${ExpansionCondition(zoo.nestedExpansion)}) {
          ${BuildCode(zoo.nestedExpansion)}
       }
    [/#if]
[/#macro]

[#var inFirstVarName = "", inFirstIndex =0]

[#macro BuildCodeOneOrMore oom]
   [#var nestedExp=oom.nestedExpansion, prevInFirstVarName = inFirstVarName/]
   [#if nestedExp.simpleName = "ExpansionChoice"]
     [#set inFirstVarName = "inFirst" + inFirstIndex, inFirstIndex = inFirstIndex +1 /]
     boolean ${inFirstVarName} = true; 
   [/#if]
   while (true) {
      [@RecoveryLoop oom /]
      [#if nestedExp.simpleName = "ExpansionChoice"]
         ${inFirstVarName} = false;
      [#else]
         if (!(${ExpansionCondition(oom.nestedExpansion)})) break;
      [/#if]
   }
   [#set inFirstVarName = prevInFirstVarName /]
[/#macro]

[#macro BuildCodeZeroOrMore zom]
    while (true) {
       [#if zom.nestedExpansion.class.simpleName != "ExpansionChoice"]
         if (!(${ExpansionCondition(zom.nestedExpansion)})) break;
       [/#if]
       [@RecoveryLoop zom/]
    }
[/#macro]

[#macro RecoveryLoop loopExpansion]
   [#if !settings.faultTolerant || !loopExpansion.requiresRecoverMethod]
       ${BuildCode(loopExpansion.nestedExpansion)}
   [#else]
       [#var initialTokenVarName = "initialToken" + CU.newID()]
       ${settings.baseTokenClassName} ${initialTokenVarName} = lastConsumedToken;
       try {
          ${BuildCode(loopExpansion.nestedExpansion)}
       } catch (ParseException pe) {
          if (!isParserTolerant()) throw pe;
//          if (debugFaultTolerant) LOGGER.info("Handling exception. Last consumed token: " + lastConsumedToken.getImage() + " at: " + lastConsumedToken.getLocation());
          if (${initialTokenVarName} == lastConsumedToken) {
             lastConsumedToken = nextToken(lastConsumedToken);
             //We have to skip a token in this spot or 
             // we'll be stuck in an infinite loop!
             lastConsumedToken.setSkipped(true);
//             if (debugFaultTolerant) LOGGER.info("Skipping token " + lastConsumedToken.getImage() + " at: " + lastConsumedToken.getLocation());
          }
//          if (debugFaultTolerant) LOGGER.info("Repeat re-sync for expansion at: ${loopExpansion.location?j_string}");
          ${loopExpansion.recoverMethodName}();
          if (pendingRecovery) throw pe;
       }
   [/#if]
[/#macro]

[#macro BuildCodeChoice choice]
   [#list choice.choices as expansion]
      [#if expansion.enteredUnconditionally]
        {
         ${BuildCode(expansion)}
        }
        [#if expansion_has_next]
            [#var nextExpansion = choice[expansion_index+1]]
            // Warning: choice at ${nextExpansion.location} is is ignored because the 
            // choice at ${expansion.location} is entered unconditionally and we jump
            // out of the loop.. 
        [/#if]
         [#return/]
      [/#if]
      if (${ExpansionCondition(expansion)}) { 
         ${BuildCode(expansion)}
      }
      [#if expansion_has_next] else [/#if]
   [/#list]
   [#if choice.parent.simpleName == "ZeroOrMore"]
      else {
         break;
      }
   [#elseif choice.parent.simpleName = "OneOrMore"]
       else if (${inFirstVarName}) {
           pushOntoCallStack("${currentProduction.name}", "${choice.inputSource?j_string}", ${choice.beginLine}, ${choice.beginColumn});
           throw new ParseException(lastConsumedToken, ${choice.firstSetVarName}, parsingStack);
       } else {
           break;
       }
   [#elseif choice.parent.simpleName != "ZeroOrOne"]
       else {
           pushOntoCallStack("${currentProduction.name}", "${choice.inputSource?j_string}", ${choice.beginLine}, ${choice.beginColumn});
           throw new ParseException(lastConsumedToken, ${choice.firstSetVarName}, parsingStack);
        }
   [/#if]
[/#macro]

[#-- 
     Macro to generate the condition for entering an expansion
     including the default single-token lookahead
--]
[#macro ExpansionCondition expansion]
    [#if expansion.requiresPredicateMethod]
       ${ScanAheadCondition(expansion)}
    [#else] 
       ${SingleTokenCondition(expansion)}
    [/#if]
[/#macro]


[#-- Generates code for when we need a scanahead --]
[#macro ScanAheadCondition expansion]
   [#if expansion.lookahead?? && expansion.lookahead.LHS??]
      (${expansion.lookahead.LHS} =
   [/#if]
   [#if expansion.hasSemanticLookahead && !expansion.lookahead.semanticLookaheadNested]
      (${expansion.semanticLookahead}) &&
   [/#if]
   ${expansion.predicateMethodName}()
   [#if expansion.lookahead?? && expansion.lookahead.LHS??]
      )
   [/#if]
[/#macro]


[#-- Generates code for when we don't need any scanahead routine --]
[#macro SingleTokenCondition expansion]
   [#if expansion.hasSemanticLookahead]
      (${expansion.semanticLookahead}) &&
   [/#if]
   [#if expansion.enteredUnconditionally]
      true 
   [#elseif expansion.firstSet.tokenNames?size ==0]
      false
   [#elseif expansion.firstSet.tokenNames?size < CU.USE_FIRST_SET_THRESHOLD] 
      [#list expansion.firstSet.tokenNames as name]
          nextTokenType [#if name_index ==0]() [/#if]
          == ${name} 
         [#if name_has_next] || [/#if] 
      [/#list]
   [#else]
      ${expansion.firstSetVarName}.contains(nextTokenType()) 
   [/#if]
[/#macro]


[#macro BuildAssertionCode assertion]
   [#var optionalPart = ""]
   [#if assertion.messageExpression??]
      [#set optionalPart = " + " + assertion.messageExpression]
   [/#if]
   [#var assertionMessage = "Assertion at: " + assertion.location?j_string + " failed. "]
   [#if assertion.assertionExpression??]
      if (!(${assertion.assertionExpression})) {
         fail("${assertionMessage}"${optionalPart}, getToken(1));
      }
   [/#if]
   [#if assertion.expansion??]
      if ( [#if !assertion.expansionNegated]![/#if]
      ${assertion.expansion.scanRoutineName}()) {
         fail("${assertionMessage}"${optionalPart}, getToken(1));
      }
   [/#if]
[/#macro]


[#--
   Macro to build routines that scan up to the start of an expansion
   as part of a recovery routine
--]
[#macro BuildRecoverRoutines]
   [#list grammar.expansionsNeedingRecoverMethod as expansion]
       private void ${expansion.recoverMethodName}() {
          ${settings.baseTokenClassName} initialToken = lastConsumedToken;
          java.util.List<${settings.baseTokenClassName}> skippedTokens = new java.util.ArrayList<>();
          boolean success = false;
          while (lastConsumedToken.getType() != EOF) {
            [#if expansion.simpleName = "OneOrMore" || expansion.simpleName = "ZeroOrMore"]
             if (${ExpansionCondition(expansion.nestedExpansion)}) {
            [#else]
             if (${ExpansionCondition(expansion)}) {
            [/#if]
                success = true;
                break;
             }
             [#if expansion.simpleName = "ZeroOrMore" || expansion.simpleName = "OneOrMore"]
               [#var followingExpansion = expansion.followingExpansion]
               [#list 1..1000000 as unused]
                [#if followingExpansion?is_null][#break][/#if]
                [#if followingExpansion.maximumSize >0] 
                 [#if followingExpansion.simpleName = "OneOrMore" || followingExpansion.simpleName = "ZeroOrOne" || followingExpansion.simpleName = "ZeroOrMore"]
                 if (${ExpansionCondition(followingExpansion.nestedExpansion)}) {
                 [#else]
                 if (${ExpansionCondition(followingExpansion)}) {
                 [/#if]
                    success = true;
                    break;
                 }
                [/#if]
                [#if !followingExpansion.possiblyEmpty][#break][/#if]
                [#if followingExpansion.followingExpansion?is_null]
                 if (outerFollowSet != null) {
                   if (outerFollowSet.contains(nextTokenType())) {
                      success = true;
                      break;
                   }
                 }
                 [#break/]
                [/#if]
                [#set followingExpansion = followingExpansion.followingExpansion]
               [/#list]
             [/#if]
             lastConsumedToken = nextToken(lastConsumedToken);
             skippedTokens.add(lastConsumedToken);
          }
          if (!success && !skippedTokens.isEmpty()) {
             lastConsumedToken = initialToken;
          } 
          if (success&& !skippedTokens.isEmpty()) {
             InvalidNode iv = new InvalidNode();
             iv.copyLocationInfo(skippedTokens.get(0));
             for (${settings.baseTokenClassName} tok : skippedTokens) {
                iv.addChild(tok);
                iv.setEndOffset(tok.getEndOffset());
             }
//             if (debugFaultTolerant) {
//                LOGGER.info("Skipping " + skippedTokens.size() + " tokens starting at: " + skippedTokens.get(0).getLocation());
//             }
             pushNode(iv);
          }
          pendingRecovery = !success;
       }
   [/#list]
[/#macro]
