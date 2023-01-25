/* Generated by: JavaCC 21 Parser Generator. JSONNfaData.java */
package org.parsers.json;

import static org.parsers.json.JSONConstants.TokenType.*;
import java.util.Arrays;
import java.util.BitSet;
/**
 * Holder class for the data used by JSONLexer
 * to do the NFA thang
 */
class JSONNfaData implements JSONConstants {
    // The functional interface that represents 
    // the acceptance method of an NFA state
    static interface NfaFunction {
        TokenType apply(int ch, BitSet bs);
    }
    static private NfaFunction[] nfaFunctions;
    // This data holder class is never instantiated
    private JSONNfaData() {
    }

    /**
   * @param the lexical state
   * @return the table of function pointers that implement the lexical state
   */
    static final NfaFunction[] getFunctionTableMap(LexicalState lexicalState) {
        // We only have one lexical state in this case, so we return that!
        return nfaFunctions;
    }

    // Initialize the various NFA method tables
    static {
        NFA_FUNCTIONS_JSON_init();
    }
    // Just use the canned binary search to check whether the char
    // is in one of the intervals
    private static final boolean checkIntervals(int[] ranges, int ch) {
        int temp;
        return(temp= Arrays.binarySearch(ranges, ch))>=0||temp%2== 0;
    }

    static TokenType NFA_COMPOSITE_JSON_0(int ch, BitSet nextStates) {
        TokenType type= null;
        if (ch== '"') {
            nextStates.set(7);
            return null;
        }
        if (ch== '-') {
            nextStates.set(1);
            return null;
        }
        if (ch== 'f') {
            nextStates.set(12);
            return null;
        }
        if (ch== 'n') {
            nextStates.set(11);
            return null;
        }
        if (ch== 't') {
            nextStates.set(34);
            return null;
        }
        if (ch== '0') {
            nextStates.set(6);
            return NUMBER;
        }
        if (ch>='1'&&ch<='9') {
            nextStates.set(4);
            return NUMBER;
        }
        if (ch== '}') {
            return CLOSE_BRACE;
        }
        if (ch== '{') {
            return OPEN_BRACE;
        }
        if (ch== ']') {
            return CLOSE_BRACKET;
        }
        if (ch== '[') {
            return OPEN_BRACKET;
        }
        if (ch== ',') {
            return COMMA;
        }
        if (ch== ':') {
            return COLON;
        }
        if (ch== '\t') {
            nextStates.set(8);
            return WHITESPACE;
        }
        if (ch== '\n') {
            nextStates.set(8);
            return WHITESPACE;
        }
        if (ch== '\r') {
            nextStates.set(8);
            return WHITESPACE;
        }
        if (ch== ' ') {
            nextStates.set(8);
            return WHITESPACE;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_1(int ch, BitSet nextStates) {
        TokenType type= null;
        if (ch== '0') {
            nextStates.set(6);
            return NUMBER;
        }
        if (ch>='1'&&ch<='9') {
            nextStates.set(4);
            return NUMBER;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_2(int ch, BitSet nextStates) {
        TokenType type= null;
        if (ch== '-') {
            nextStates.set(1);
            return null;
        }
        if (ch== '0') {
            nextStates.set(6);
            return NUMBER;
        }
        if (ch>='1'&&ch<='9') {
            nextStates.set(4);
            return NUMBER;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_3(int ch, BitSet nextStates) {
        TokenType type= null;
        if ((ch== 'E')||(ch== 'e')) {
            nextStates.set(9);
            return null;
        }
        if (ch>='0'&&ch<='9') {
            nextStates.set(3);
            return NUMBER;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_4(int ch, BitSet nextStates) {
        TokenType type= null;
        if (ch== '.') {
            nextStates.set(39);
            return null;
        }
        if ((ch== 'E')||(ch== 'e')) {
            nextStates.set(9);
            return null;
        }
        if (ch>='0'&&ch<='9') {
            nextStates.set(4);
            return NUMBER;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_5(int ch, BitSet nextStates) {
        TokenType type= null;
        if ((ch== ' '||ch== '!')||((ch>='#'&&ch<='[')||(ch>=']'))) {
            nextStates.set(7);
            return null;
        }
        if (ch== '\\') {
            nextStates.set(27);
            nextStates.set(25);
            return null;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_6(int ch, BitSet nextStates) {
        TokenType type= null;
        if (ch== '.') {
            nextStates.set(39);
            return null;
        }
        if ((ch== 'E')||(ch== 'e')) {
            nextStates.set(9);
            return null;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_7(int ch, BitSet nextStates) {
        TokenType type= null;
        if ((ch== ' '||ch== '!')||((ch>='#'&&ch<='[')||(ch>=']'))) {
            nextStates.set(7);
            return null;
        }
        if (ch== '\\') {
            nextStates.set(27);
            nextStates.set(25);
            return null;
        }
        if (ch== '"') {
            return STRING_LITERAL;
        }
        return type;
    }

    static TokenType NFA_COMPOSITE_JSON_8(int ch, BitSet nextStates) {
        TokenType type= null;
        if (ch== '\t') {
            nextStates.set(8);
            return WHITESPACE;
        }
        if (ch== '\n') {
            nextStates.set(8);
            return WHITESPACE;
        }
        if (ch== '\r') {
            nextStates.set(8);
            return WHITESPACE;
        }
        if (ch== ' ') {
            nextStates.set(8);
            return WHITESPACE;
        }
        return type;
    }

    static TokenType NFA_JSON_9(int ch, BitSet nextStates) {
        if ((ch== '+')||(ch== '-')) {
            nextStates.set(24);
        }
        return null;
    }

    static TokenType NFA_JSON_10(int ch, BitSet nextStates) {
        if (ch== 'n') {
            nextStates.set(11);
        }
        return null;
    }

    static TokenType NFA_JSON_11(int ch, BitSet nextStates) {
        if (ch== 'u') {
            nextStates.set(33);
        }
        return null;
    }

    static TokenType NFA_JSON_12(int ch, BitSet nextStates) {
        if (ch== 'a') {
            nextStates.set(18);
        }
        return null;
    }

    static TokenType NFA_JSON_13(int ch, BitSet nextStates) {
        if (ch== 't') {
            nextStates.set(34);
        }
        return null;
    }

    static TokenType NFA_JSON_14(int ch, BitSet nextStates) {
        if (ch== '{') {
            return OPEN_BRACE;
        }
        return null;
    }

    static TokenType NFA_JSON_15(int ch, BitSet nextStates) {
        if (ch== 'e') {
            return TRUE;
        }
        return null;
    }

    static TokenType NFA_JSON_16(int ch, BitSet nextStates) {
        if (ch== ']') {
            return CLOSE_BRACKET;
        }
        return null;
    }

    static TokenType NFA_JSON_17(int ch, BitSet nextStates) {
        if (ch== ',') {
            return COMMA;
        }
        return null;
    }

    static TokenType NFA_JSON_18(int ch, BitSet nextStates) {
        if (ch== 'l') {
            nextStates.set(26);
        }
        return null;
    }

    static TokenType NFA_JSON_19(int ch, BitSet nextStates) {
        if (ch== 'e') {
            return FALSE;
        }
        return null;
    }

    static TokenType NFA_JSON_20(int ch, BitSet nextStates) {
        if (ch== '}') {
            return CLOSE_BRACE;
        }
        return null;
    }

    static TokenType NFA_JSON_21(int ch, BitSet nextStates) {
        if (ch== '"') {
            nextStates.set(7);
        }
        return null;
    }

    static TokenType NFA_JSON_22(int ch, BitSet nextStates) {
        if (ch== ':') {
            return COLON;
        }
        return null;
    }

    static TokenType NFA_JSON_23(int ch, BitSet nextStates) {
        if (ch== '[') {
            return OPEN_BRACKET;
        }
        return null;
    }

    static TokenType NFA_JSON_24(int ch, BitSet nextStates) {
        if (ch>='1'&&ch<='9') {
            nextStates.set(24);
            return NUMBER;
        }
        return null;
    }

    static private int[] NFA_MOVES_JSON_25= NFA_MOVES_JSON_25_init();
    static private int[] NFA_MOVES_JSON_25_init() {
        int[] result= new int[16];
        result[0]= '"';
        result[1]= '"';
        result[2]= '/';
        result[3]= '/';
        result[4]= '\\';
        result[5]= '\\';
        result[6]= 'b';
        result[7]= 'b';
        result[8]= 'f';
        result[9]= 'f';
        result[10]= 'n';
        result[11]= 'n';
        result[12]= 'r';
        result[13]= 'r';
        result[14]= 't';
        result[15]= 't';
        return result;
    }

    static TokenType NFA_JSON_25(int ch, BitSet nextStates) {
        if (checkIntervals(NFA_MOVES_JSON_25, ch)) {
            nextStates.set(7);
        }
        return null;
    }

    static TokenType NFA_JSON_26(int ch, BitSet nextStates) {
        if (ch== 's') {
            nextStates.set(19);
        }
        return null;
    }

    static TokenType NFA_JSON_27(int ch, BitSet nextStates) {
        if (ch== 'u') {
            nextStates.set(28);
        }
        return null;
    }

    static TokenType NFA_JSON_28(int ch, BitSet nextStates) {
        if ((ch>='0'&&ch<='9')||((ch>='A'&&ch<='F')||(ch>='a'&&ch<='f'))) {
            nextStates.set(36);
        }
        return null;
    }

    static TokenType NFA_JSON_29(int ch, BitSet nextStates) {
        if (ch== 'u') {
            nextStates.set(15);
        }
        return null;
    }

    static TokenType NFA_JSON_30(int ch, BitSet nextStates) {
        if ((ch>='0'&&ch<='9')||((ch>='A'&&ch<='F')||(ch>='a'&&ch<='f'))) {
            nextStates.set(7);
        }
        return null;
    }

    static TokenType NFA_JSON_31(int ch, BitSet nextStates) {
        if (ch== 'l') {
            return NULL;
        }
        return null;
    }

    static TokenType NFA_JSON_32(int ch, BitSet nextStates) {
        if ((ch>='0'&&ch<='9')||((ch>='A'&&ch<='F')||(ch>='a'&&ch<='f'))) {
            nextStates.set(30);
        }
        return null;
    }

    static TokenType NFA_JSON_33(int ch, BitSet nextStates) {
        if (ch== 'l') {
            nextStates.set(31);
        }
        return null;
    }

    static TokenType NFA_JSON_34(int ch, BitSet nextStates) {
        if (ch== 'r') {
            nextStates.set(29);
        }
        return null;
    }

    static TokenType NFA_JSON_35(int ch, BitSet nextStates) {
        if (ch== 'f') {
            nextStates.set(12);
        }
        return null;
    }

    static TokenType NFA_JSON_36(int ch, BitSet nextStates) {
        if ((ch>='0'&&ch<='9')||((ch>='A'&&ch<='F')||(ch>='a'&&ch<='f'))) {
            nextStates.set(32);
        }
        return null;
    }

    static TokenType NFA_JSON_37(int ch, BitSet nextStates) {
        if ((ch== 'E')||(ch== 'e')) {
            nextStates.set(9);
        }
        return null;
    }

    static TokenType NFA_JSON_38(int ch, BitSet nextStates) {
        if (ch== '\n') {
            nextStates.set(8);
            return WHITESPACE;
        }
        return null;
    }

    static TokenType NFA_JSON_39(int ch, BitSet nextStates) {
        if (ch>='0'&&ch<='9') {
            nextStates.set(3);
            return NUMBER;
        }
        return null;
    }

    static TokenType NFA_JSON_40(int ch, BitSet nextStates) {
        if (ch== '-') {
            nextStates.set(1);
        }
        return null;
    }

    static TokenType NFA_JSON_41(int ch, BitSet nextStates) {
        if ((ch== ' '||ch== '!')||((ch>='#'&&ch<='[')||(ch>=']'))) {
            nextStates.set(7);
        }
        return null;
    }

    static TokenType NFA_JSON_42(int ch, BitSet nextStates) {
        if (ch== '\r') {
            nextStates.set(8);
            return WHITESPACE;
        }
        return null;
    }

    static TokenType NFA_JSON_43(int ch, BitSet nextStates) {
        if (ch== '"') {
            return STRING_LITERAL;
        }
        return null;
    }

    static TokenType NFA_JSON_44(int ch, BitSet nextStates) {
        if (ch>='1'&&ch<='9') {
            nextStates.set(4);
            return NUMBER;
        }
        return null;
    }

    static TokenType NFA_JSON_45(int ch, BitSet nextStates) {
        if (ch== ' ') {
            nextStates.set(8);
            return WHITESPACE;
        }
        return null;
    }

    static TokenType NFA_JSON_46(int ch, BitSet nextStates) {
        if (ch== '.') {
            nextStates.set(39);
        }
        return null;
    }

    static TokenType NFA_JSON_47(int ch, BitSet nextStates) {
        if (ch>='0'&&ch<='9') {
            nextStates.set(4);
            return NUMBER;
        }
        return null;
    }

    static TokenType NFA_JSON_48(int ch, BitSet nextStates) {
        if (ch== '\\') {
            nextStates.set(27);
        }
        return null;
    }

    static TokenType NFA_JSON_49(int ch, BitSet nextStates) {
        if (ch== '\\') {
            nextStates.set(25);
        }
        return null;
    }

    static TokenType NFA_JSON_50(int ch, BitSet nextStates) {
        if (ch== '\t') {
            nextStates.set(8);
            return WHITESPACE;
        }
        return null;
    }

    static TokenType NFA_JSON_51(int ch, BitSet nextStates) {
        if (ch== '0') {
            nextStates.set(6);
            return NUMBER;
        }
        return null;
    }

    static private void NFA_FUNCTIONS_JSON_init() {
        NfaFunction[] functions= new NfaFunction[52];
        functions[0]= JSONNfaData::NFA_COMPOSITE_JSON_0;
        functions[1]= JSONNfaData::NFA_COMPOSITE_JSON_1;
        functions[2]= JSONNfaData::NFA_COMPOSITE_JSON_2;
        functions[3]= JSONNfaData::NFA_COMPOSITE_JSON_3;
        functions[4]= JSONNfaData::NFA_COMPOSITE_JSON_4;
        functions[5]= JSONNfaData::NFA_COMPOSITE_JSON_5;
        functions[6]= JSONNfaData::NFA_COMPOSITE_JSON_6;
        functions[7]= JSONNfaData::NFA_COMPOSITE_JSON_7;
        functions[8]= JSONNfaData::NFA_COMPOSITE_JSON_8;
        functions[9]= JSONNfaData::NFA_JSON_9;
        functions[10]= JSONNfaData::NFA_JSON_10;
        functions[11]= JSONNfaData::NFA_JSON_11;
        functions[12]= JSONNfaData::NFA_JSON_12;
        functions[13]= JSONNfaData::NFA_JSON_13;
        functions[14]= JSONNfaData::NFA_JSON_14;
        functions[15]= JSONNfaData::NFA_JSON_15;
        functions[16]= JSONNfaData::NFA_JSON_16;
        functions[17]= JSONNfaData::NFA_JSON_17;
        functions[18]= JSONNfaData::NFA_JSON_18;
        functions[19]= JSONNfaData::NFA_JSON_19;
        functions[20]= JSONNfaData::NFA_JSON_20;
        functions[21]= JSONNfaData::NFA_JSON_21;
        functions[22]= JSONNfaData::NFA_JSON_22;
        functions[23]= JSONNfaData::NFA_JSON_23;
        functions[24]= JSONNfaData::NFA_JSON_24;
        functions[25]= JSONNfaData::NFA_JSON_25;
        functions[26]= JSONNfaData::NFA_JSON_26;
        functions[27]= JSONNfaData::NFA_JSON_27;
        functions[28]= JSONNfaData::NFA_JSON_28;
        functions[29]= JSONNfaData::NFA_JSON_29;
        functions[30]= JSONNfaData::NFA_JSON_30;
        functions[31]= JSONNfaData::NFA_JSON_31;
        functions[32]= JSONNfaData::NFA_JSON_32;
        functions[33]= JSONNfaData::NFA_JSON_33;
        functions[34]= JSONNfaData::NFA_JSON_34;
        functions[35]= JSONNfaData::NFA_JSON_35;
        functions[36]= JSONNfaData::NFA_JSON_36;
        functions[37]= JSONNfaData::NFA_JSON_37;
        functions[38]= JSONNfaData::NFA_JSON_38;
        functions[39]= JSONNfaData::NFA_JSON_39;
        functions[40]= JSONNfaData::NFA_JSON_40;
        functions[41]= JSONNfaData::NFA_JSON_41;
        functions[42]= JSONNfaData::NFA_JSON_42;
        functions[43]= JSONNfaData::NFA_JSON_43;
        functions[44]= JSONNfaData::NFA_JSON_44;
        functions[45]= JSONNfaData::NFA_JSON_45;
        functions[46]= JSONNfaData::NFA_JSON_46;
        functions[47]= JSONNfaData::NFA_JSON_47;
        functions[48]= JSONNfaData::NFA_JSON_48;
        functions[49]= JSONNfaData::NFA_JSON_49;
        functions[50]= JSONNfaData::NFA_JSON_50;
        functions[51]= JSONNfaData::NFA_JSON_51;
        nfaFunctions= functions;
    }

}
