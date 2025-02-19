 /*
  * Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb}
  */
package ${settings.parserPackage};

#if settings.treeBuildingEnabled
  import ${settings.nodePackage}.*;
#endif

import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;

#if settings.rootAPIPackage
  import ${settings.rootAPIPackage}.Node;
  import ${settings.rootAPIPackage}.TokenSource;
#endif

#var implements = "implements CharSequence"

#if settings.treeBuildingEnabled
    #set implements = "implements CharSequence, Node.TerminalNode"
    #if settings.rootAPIPackage
       import ${settings.rootAPIPackage}.Node;
    #endif
#endif

public class ${settings.baseTokenClassName} ${implements} {

    public enum TokenType
    #if settings.treeBuildingEnabled
       implements Node.NodeType
    #endif
    {
       #list lexerData.regularExpressions as regexp
          ${regexp.label}
          #if regexp.class.simpleName == "RegexpStringLiteral" && !regexp.ignoreCase
            ("${regexp.literalString?j_string}")
          #endif
          ,
       #endlist
       #list settings.extraTokenNames as extraToken
          ${extraToken},
       #endlist
       DUMMY,
       INVALID;

       TokenType() {}

       TokenType(String literalString) {
          this.literalString = literalString;
       }

       private String literalString;

       public String getLiteralString() {
           return literalString;
       }

       public boolean isUndefined() {return this == DUMMY;}
       public boolean isInvalid() {return this == INVALID;}
       public boolean isEOF() {return this == EOF;}
    }

    private ${settings.lexerClassName} tokenSource;

    private TokenType type = TokenType.DUMMY;

    private int beginOffset;
    private int endOffset;

    private boolean unparsed;

#if settings.treeBuildingEnabled
    private Node parent;
#endif

#if !settings.minimalToken
    private String cachedImage;
    /**
     * If cachedImage is set, then the various methods
     * that implement #java.lang.CharSequence use that string
     * rather than what is returned by getSource()
     */
    public void setCachedImage(String image) {
        this.cachedImage = image;
    }

    public String getCachedImage() {
        return this.cachedImage;
    }

    /**
     * @param type the #TokenType of the token being constructed
     * @param image the String content of the token
     * @param tokenSource the object that vended this token.
     */
    public ${settings.baseTokenClassName}(TokenType type, String image, ${settings.lexerClassName} tokenSource) {
        this.type = type;
        this.cachedImage = image;
        this.tokenSource = tokenSource;
    }

#endif

    public void truncate(int amount) {
        int newEndOffset = Math.max(getBeginOffset(), getEndOffset()-amount);
        setEndOffset(newEndOffset);
   #if !settings.minimalToken
        if (cachedImage != null) {
            cachedImage = cachedImage.substring(0, newEndOffset - getBeginOffset());
        }
   #endif
    }


#if settings.tokenChaining

    private ${settings.baseTokenClassName} prependedToken;
    private ${settings.baseTokenClassName} appendedToken;

    private boolean inserted;

    public boolean isInserted() {return inserted;}


    public void preInsert(${settings.baseTokenClassName} prependedToken) {
        if (prependedToken == this.prependedToken) return;
        prependedToken.appendedToken = this;
        ${settings.baseTokenClassName} existingPreviousToken = this.previousCachedToken();
        if (existingPreviousToken != null) {
            existingPreviousToken.appendedToken = prependedToken;
            prependedToken.prependedToken = existingPreviousToken;
        }
        prependedToken.inserted = true;
        prependedToken.beginOffset = prependedToken.endOffset = this.beginOffset;
        this.prependedToken = prependedToken;
    }

    void unsetAppendedToken() {
        this.appendedToken = null;
    }

#endif

    /**
     * It would be extremely rare that an application
     * programmer would use this method. It needs to
     * be public because it is part of the ${settings.parserPackage}.Node interface.
     */
    public void setBeginOffset(int beginOffset) {
        this.beginOffset = beginOffset;
    }

    /**
     * It would be extremely rare that an application
     * programmer would use this method. It needs to
     * be public because it is part of the ${settings.parserPackage}.Node interface.
     */
    public void setEndOffset(int endOffset) {
        this.endOffset = endOffset;
    }

    /**
     * @return the ${settings.lexerClassName} object that handles
     * location info for the tokens.
     */
    public ${settings.lexerClassName} getTokenSource() {
        return tokenSource;
    }

    /**
     * @return the line of source which contains the token.
     * This can be useful in error reporting.
     */
    public String getSourceLine() {
        return tokenSource.getLine(this);
    }

    /**
     * It should be exceedingly rare that an application
     * programmer needs to use this method.
     */
    public void setTokenSource(TokenSource tokenSource) {
        this.tokenSource = (${settings.lexerClassName}) tokenSource;
    }

    public boolean isInvalid() {
        return getType().isInvalid();
    }

    /**
     * Return the TokenType of this ${settings.baseTokenClassName} object
     */
#if settings.treeBuildingEnabled
    @Override
#endif
    public TokenType getType() {
        return type;
    }

    protected void setType(TokenType type) {
        this.type = type;
    }

    /**
     * @return whether this ${settings.baseTokenClassName} represent actual input or was it inserted somehow?
     */
    public boolean isVirtual() {
        #if settings.faultTolerant
            return virtual || type == TokenType.EOF;
        #else
            return type == TokenType.EOF;
        #endif
    }

    /**
     * @return Did we skip this token in parsing?
     */
    public boolean isSkipped() {
        #if settings.faultTolerant
           return skipped;
        #else
           return false;
        #endif
    }


#if settings.faultTolerant
    private boolean virtual;
    private boolean skipped;
    private boolean dirty;

    void setVirtual(boolean virtual) {
        this.virtual = virtual;
        if (virtual) dirty = true;
    }

    void setSkipped(boolean skipped) {
        this.skipped = skipped;
        if (skipped) dirty = true;
    }

    public boolean isDirty() {
        return dirty;
    }

    public void setDirty(boolean dirty) {
        this.dirty = dirty;
    }

#endif


#if !settings.treeBuildingEnabled
 [#-- If tree building is enabled, we can simply use the default
      implementation in the Node interface--]
    /**
     * @return the (1-based) line location where this ${settings.baseTokenClassName} starts
     */
    public int getBeginLine() {
        ${settings.lexerClassName} ts = getTokenSource();
        return ts == null ? 0 : ts.getLineFromOffset(getBeginOffset());
    };

    /**
     * @return the (1-based) line location where this ${settings.baseTokenClassName} ends
     */
    public int getEndLine() {
        ${settings.lexerClassName} ts = getTokenSource();
        return ts == null ? 0 : ts.getLineFromOffset(getEndOffset() - 1);
    };

    /**
     * @return the (1-based) column where this ${settings.baseTokenClassName} starts
     */
    public int getBeginColumn() {
        ${settings.lexerClassName} ts = getTokenSource();
        return ts == null ? 0 : ts.getCodePointColumnFromOffset(getBeginOffset());
    };

    /**
     * @return the (1-based) column offset where this ${settings.baseTokenClassName} ends
     */
    public int getEndColumn() {
        ${settings.lexerClassName} ts = getTokenSource();
        return ts == null ? 0 : ts.getCodePointColumnFromOffset(getEndOffset() - 1);
    }

    public String getInputSource() {
        ${settings.lexerClassName} ts = getTokenSource();
        return ts != null ? ts.getInputSource() : "input";
    }
#endif

    public int getBeginOffset() {
        return beginOffset;
    }

    public int getEndOffset() {
        return endOffset;
    }

    /**
     * @return the next _cached_ regular (i.e. parsed) token
     * or null
     */
#if settings.treeBuildingEnabled
   @Override
#endif
    public final ${settings.baseTokenClassName} getNext() {
        return getNextParsedToken();
    }

    /**
     * @return the previous regular (i.e. parsed) token
     * or null
     */
    public final ${settings.baseTokenClassName} getPrevious() {
        ${settings.baseTokenClassName} result = previousCachedToken();
        while (result != null && result.isUnparsed()) {
            result = result.previousCachedToken();
        }
        return result;
    }

    /**
     * @return the next regular (i.e. parsed) token
     */
    private ${settings.baseTokenClassName} getNextParsedToken() {
        ${settings.baseTokenClassName} result = nextCachedToken();
        while (result != null && result.isUnparsed()) {
            result = result.nextCachedToken();
        }
        return result;
    }

    /**
     * @return the next token of any sort (parsed or unparsed or invalid)
     */
    public ${settings.baseTokenClassName} nextCachedToken() {
        if (getType() == TokenType.EOF) return null;
#if settings.tokenChaining
        if (appendedToken != null) return appendedToken;
#endif
        ${settings.lexerClassName} tokenSource = getTokenSource();
        return tokenSource != null ? (${settings.baseTokenClassName}) tokenSource.nextCachedToken(getEndOffset()) : null;
    }

    public ${settings.baseTokenClassName} previousCachedToken() {
#if settings.tokenChaining
        if (prependedToken != null) return prependedToken;
#endif
        if (getTokenSource() == null) return null;
        return (${settings.baseTokenClassName}) getTokenSource().previousCachedToken(getBeginOffset());
    }

    ${settings.baseTokenClassName} getPreviousToken() {
        return previousCachedToken();
    }

    public ${settings.baseTokenClassName} replaceType(TokenType type) {
        ${settings.baseTokenClassName} result = newToken(type, getTokenSource(), getBeginOffset(), getEndOffset());
#if !settings.minimalToken
        result.cachedImage = this.cachedImage;
#endif
#if settings.tokenChaining
        result.prependedToken = this.prependedToken;
        result.appendedToken = this.appendedToken;
        result.inserted = this.inserted;
        if (result.appendedToken != null) {
            result.appendedToken.prependedToken = result;
        }
        if (result.prependedToken != null) {
            result.prependedToken.appendedToken = result;
        }
        if (!result.inserted) {
            getTokenSource().cacheToken(result);
        }
#else
        getTokenSource().cacheToken(result);
#endif
        return result;
    }

    public String getSource() {
         if (type == TokenType.EOF) return "";
         ${settings.lexerClassName} ts = getTokenSource();
         int beginOffset = getBeginOffset();
         int endOffset = getEndOffset();
         return ts == null || beginOffset<=0 && endOffset <=0 ? null : ts.getText(beginOffset, endOffset);
    }

    protected ${settings.baseTokenClassName}() {}

    public ${settings.baseTokenClassName}(TokenType type, ${settings.lexerClassName} tokenSource, int beginOffset, int endOffset) {
        this.type = type;
        this.tokenSource = tokenSource;
        this.beginOffset = beginOffset;
        this.endOffset = endOffset;
    }

    public boolean isUnparsed() {
        return unparsed;
    }

    public void setUnparsed(boolean unparsed) {
        this.unparsed = unparsed;
    }



    /**
     * @return An iterator of the tokens preceding this one.
     */
    public Iterator<${settings.baseTokenClassName}> precedingTokens() {
        return new Iterator<${settings.baseTokenClassName}>() {
            ${settings.baseTokenClassName} currentPoint = ${settings.baseTokenClassName}.this;
            public boolean hasNext() {
                return currentPoint.previousCachedToken() != null;
            }
            public ${settings.baseTokenClassName} next() {
                ${settings.baseTokenClassName} previous = currentPoint.previousCachedToken();
                if (previous == null) throw new java.util.NoSuchElementException("No previous token!");
                return currentPoint = previous;
            }
        };
    }

    /**
     * @return a list of the unparsed tokens preceding this one in the order they appear in the input
     */
    public List<${settings.baseTokenClassName}> precedingUnparsedTokens() {
        List<${settings.baseTokenClassName}> result = new ArrayList<>();
        ${settings.baseTokenClassName} t = this.previousCachedToken();
        while (t != null && t.isUnparsed()) {
            result.add(t);
            t = t.previousCachedToken();
        }
        Collections.reverse(result);
        return result;
    }

    /**
     * @return An iterator of the (cached) tokens that follow this one.
     */
    public Iterator<${settings.baseTokenClassName}> followingTokens() {
        return new java.util.Iterator<${settings.baseTokenClassName}>() {
            ${settings.baseTokenClassName} currentPoint = ${settings.baseTokenClassName}.this;
            public boolean hasNext() {
                return currentPoint.nextCachedToken() != null;
            }
            public ${settings.baseTokenClassName} next() {
                ${settings.baseTokenClassName} next = currentPoint.nextCachedToken();
                if (next == null) throw new java.util.NoSuchElementException("No next token!");
                return currentPoint = next;
            }
        };
    }

#if settings.treeBuildingEnabled && settings.tokenChaining
    /**
     * Copy the location info from a Node
     */
    public void copyLocationInfo(Node from) {
        Node.TerminalNode.super.copyLocationInfo(from);
        if (from instanceof ${settings.baseTokenClassName}) {
            ${settings.baseTokenClassName} otherTok = (${settings.baseTokenClassName}) from;
            appendedToken = otherTok.appendedToken;
            prependedToken = otherTok.prependedToken;
        }
        setTokenSource(from.getTokenSource());
    }

    public void copyLocationInfo(Node start, Node end) {
        Node.TerminalNode.super.copyLocationInfo(start, end);
        if (start instanceof ${settings.baseTokenClassName}) {
            prependedToken = ((${settings.baseTokenClassName}) start).prependedToken;
        }
        if (end instanceof ${settings.baseTokenClassName}) {
            ${settings.baseTokenClassName} endToken = (${settings.baseTokenClassName}) end;
            appendedToken = endToken.appendedToken;
        }
    }
#else
    public void copyLocationInfo(${settings.baseTokenClassName} from) {
        setTokenSource(from.getTokenSource());
        setBeginOffset(from.getBeginOffset());
        setEndOffset(from.getEndOffset());
    #if settings.tokenChaining
        appendedToken = from.appendedToken;
        prependedToken = from.prependedToken;
    #endif
    }

    public void copyLocationInfo(${settings.baseTokenClassName} start, ${settings.baseTokenClassName} end) {
        setTokenSource(start.getTokenSource());
        if (tokenSource == null) setTokenSource(end.getTokenSource());
        setBeginOffset(start.getBeginOffset());
        setEndOffset(end.getEndOffset());
    #if settings.tokenChaining
        prependedToken = start.prependedToken;
        appendedToken = end.appendedToken;
    #endif
    }
#endif

    public static ${settings.baseTokenClassName} newToken(TokenType type, ${settings.lexerClassName} tokenSource) {
        ${settings.baseTokenClassName} result = newToken(type, tokenSource, 0, 0);
        #if settings.tokenChaining
        result.inserted = true;
        #endif
        #if settings.faultTolerant
        result.virtual = true;
        #endif
        return result;
    }

    public static ${settings.baseTokenClassName} newToken(TokenType type, String image, ${settings.lexerClassName} tokenSource) {
        ${settings.baseTokenClassName} newToken = newToken(type, tokenSource);
        #if !settings.minimalToken
           newToken.setCachedImage(image);
        #endif
        return newToken;
    }


    public static ${settings.baseTokenClassName} newToken(TokenType type, ${settings.lexerClassName} tokenSource, int beginOffset, int endOffset) {
       #if settings.treeBuildingEnabled
           switch(type) {
           #list lexerData.orderedNamedTokens as re
            #if re.generatedClassName != "${settings.baseTokenClassName}" && !re.private
              #var generatedClassName = re.generatedClassName
              #if generatedClassName?index_of('.') < 0
                 #set generatedClassName = grammar.nodePrefix + generatedClassName
              #endif
              case ${re.label} : return new ${generatedClassName}(TokenType.${re.label}, tokenSource, beginOffset, endOffset);
            #endif
           #endlist
           #list settings.extraTokenNames as tokenName
              case ${tokenName} : return new ${grammar.nodePrefix}${settings.extraTokens[tokenName]}(TokenType.${tokenName}, tokenSource, beginOffset, endOffset);
           #endlist
              case INVALID : return new InvalidToken(tokenSource, beginOffset, endOffset);
              default : return new ${settings.baseTokenClassName}(type, tokenSource, beginOffset, endOffset);
           }
       #else
         return new ${settings.baseTokenClassName}(type, tokenSource, beginOffset, endOffset);
       #endif
    }

    public String getLocation() {
        return getInputSource() + ":" + getBeginLine() + ":" + getBeginColumn();
     }

#if settings.treeBuildingEnabled

    public Node getParent() {
        return parent;
    }

    public void setParent(Node parent) {
        this.parent = parent;
    }

    public boolean isEmpty() {
        return length() == 0;
    }

#endif

#if settings.usesPreprocessor
   private Boolean spansPPInstruction;
   protected boolean spansPPInstruction() {
      if (spansPPInstruction == null) {
          spansPPInstruction = getTokenSource().spansPPInstruction(beginOffset, endOffset);
      }
      return spansPPInstruction;
   }
#endif

   public int length() {
      #if !settings.minimalToken
         if (cachedImage != null) return cachedImage.length();
         cachedImage = toString();
         return cachedImage.length();
      #elif settings.usesPreprocessor
         if (spansPPInstruction()) return getTokenSource().length(beginOffset, endOffset);
         return endOffset - beginOffset;
      #else
         return endOffset - beginOffset;
      #endif
   }

   public CharSequence subSequence(int start, int end) {
      #if !settings.minimalToken
          if (cachedImage != null) return cachedImage.substring(start, end);
      #endif
      #if settings.usesPreprocessor
         if (spansPPInstruction()) {
            StringBuilder buf = new StringBuilder();
            TokenSource ts = getTokenSource();
            int scanTo = beginOffset + end;
            for (int i = beginOffset + start; i < scanTo; i++) {
                if (ts.isIgnored(i)) ++scanTo;
                else buf.append(ts.charAt(i));
            }
            return buf;
         }
      #endif
      return getTokenSource().subSequence(beginOffset + start, beginOffset+end);
   }

   public char charAt(int offset) {
      #if !settings.minimalToken
          if (cachedImage != null) return cachedImage.charAt(offset);
          cachedImage = toString();
          return cachedImage.charAt(offset);
      #elif settings.usesPreprocessor
          TokenSource ts = getTokenSource();
          int scanTo = beginOffset + offset;
          if (spansPPInstruction()) {
             int index = beginOffset;
             while (index < scanTo) {
                if (ts.isIgnored(index)) ++scanTo;
                ++index;
             }
          }
          return ts.charAt(scanTo);
      #else
          return getTokenSource().charAt(beginOffset + offset);
      #endif
   }

    /**
#if settings.minimalToken
     * @deprecated Use toString() instead
#else
     * @deprecated Typically use just toString() or occasionally getCachedImage()
#endif
     */
    @Deprecated
    public String getImage() {
      return toString();
    }


    @Override
    public String toString() {
      #if !settings.minimalToken
        if (cachedImage != null) {
            return cachedImage;
        }
      #endif
      String result = getSource();
      if (result == null) {
          result = getType().getLiteralString();
      }
      return result;
    }
}
