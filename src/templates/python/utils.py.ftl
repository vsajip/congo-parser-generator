[#ftl strict_vars=true]
# Parser utils package. Generated by ${generated_by}. Do not edit.
from math import ceil
import re

__all__ = [
    # used in lexer
    'BitSet',
    'as_chr',
    # used in parser
    'EMPTY_SET',
    'ListIterator',
    'StringBuilder',
    '_Set',
    '_List',
    'HashSet'
]

CODING_PATTERN = re.compile(rb'^[ \t\f]*#.*coding[:=][ \t]*([-_.a-zA-Z0-9]+)')

EMPTY_SET = frozenset()


def as_chr(o):
    if isinstance(o, int):
        return chr(o)
    return o


INT_BITSIZE = 64
BIT_MASK = (1 << 64) - 1
ALL_SET = (1 << INT_BITSIZE) - 1
ALL_CLEAR = 0

BIT_POS = {}
for i in range(INT_BITSIZE):
    BIT_POS[1 << i] = i


def _ints_needed(bits):
    return int(ceil(bits / INT_BITSIZE))


[#var optimize_bitset = true]
[#var cache_empty = true]
[#var toggle_needed = false]
class BitSet:

    __slots__ = ('bits', 'ints', 'max_pos'[#if cache_empty], '_empty'[/#if])

    def __init__(self, bits=None):
        self.bits = bits
        self.ints = []
[#if cache_empty]
        self._empty = True
[/#if]
        self.max_pos = 0  # highest value accessed for when bits is None
        if bits is not None:
            self.ints = [ALL_CLEAR for i in range(_ints_needed(bits))]
            self.max_pos = bits - 1

[#if !optimize_bitset]
    def _check_pos(self, pos):
        if pos < 0:
            raise ValueError(f'bit position {pos} cannot be negative')
        if self.bits is None:
            idx = _ints_needed(pos + 1)
            n = len(self.ints)
            if idx > n:
                self.ints.extend([ALL_CLEAR] * (idx - n))
            self.max_pos = max(self.max_pos, pos)
        elif pos > self.bits:
            raise ValueError(f'bit position {pos} exceeds BitSet capacity of {self.bits}')

    def _idx_and_bit(self, pos):
        self._check_pos(pos)
        return divmod(pos, INT_BITSIZE)

[/#if]
    def set(self, pos=-1, value=1):
        if pos == -1:
            value = ALL_SET if value == 1 else ALL_CLEAR
            for i in range(len(self.ints)):
                self.ints[i] = value
        else:
[#if optimize_bitset]
            idx, bit = divmod(pos, INT_BITSIZE)
[#else]
            idx, bit = self._idx_and_bit(pos)
[/#if]
            if value:
                self.ints[idx] |= (1 << bit)
            else:
                self.ints[idx] &= ~(1 << bit)
[#if cache_empty]
        # If None, we need to recompute _empty
        self._empty = False if value else None
[/#if]

    def clear(self, pos=-1, upto=-1):
        if upto == -1:
            self.set(pos, value=0)
        else:
            assert pos >= 0 and pos < upto
[#if optimize_bitset]
            idx1, bit1 = divmod(pos, INT_BITSIZE)
            idx2, bit2 = divmod(upto - 1, INT_BITSIZE)
[#else]
            idx1, bit1 = self._idx_and_bit(pos)
            idx2, bit2 = self._idx_and_bit(upto - 1)
[/#if]
            if idx1 == idx2 and bit1 == bit2:
                # just 1 bit to do
                mask1 = 1 << bit1
                self.ints[idx1] &= ~mask1
            elif idx1 == idx2:
                # just one int to do
                mask1 = (1 << bit1) - 1
                mask2 = ((~((1 << bit2) - 1)) << 1) & BIT_MASK
                self.ints[idx1] &= (mask1 | mask2)
            else:
                mask1 = (1 << bit1) - 1
                mask2 = ((~((1 << bit2) - 1)) << 1) & BIT_MASK
                self.ints[idx1] &= mask1
                self.ints[idx2] &= mask2
                # any in between first and last get zeroed
                idx1 += 1
                while idx1 < idx2:
                    self.ints[idx1] = 0
                    idx1 += 1
[#if cache_empty]
        self._empty = None
[/#if]

[#if toggle_needed]
    def _flip_all(self):
        for i in range(len(self.ints)):
            self.ints[i] ^= ALL_SET
[#if cache_empty]
        # If None, we need to recompute _empty
        self._empty = None
[/#if]

    def toggle(self, pos=-1):
        if pos == -1:
            self._flip_all()
        else:
[#if optimize_bitset]
            idx, bit = divmod(pos, INT_BITSIZE)
[#else]
            idx, bit = self._idx_and_bit(pos)
[/#if]
            self.ints[idx] ^= (1 << bit)
[#if cache_empty]
            # If None, we need to recompute _empty
            self._empty = None
[/#if]

[/#if]
    def __getitem__(self, pos):
[#if optimize_bitset]
        idx, bit = divmod(pos, INT_BITSIZE)
[#else]
        idx, bit = self._idx_and_bit(pos)
[/#if]
        return int(self.ints[idx] & (1 << bit) > 0)

[#if !cache_empty]
    @property
    def is_empty(self):
        last = len(self.ints) - 1
        for i, v in enumerate(self.ints):
            if i < last:
                if v != ALL_CLEAR:
                    return False
            else:
                # last int needs special handling. Only check bits
                # below max_pos
                idx, bit = divmod(self.max_pos + 1, INT_BITSIZE)
                if idx == i:
                    mask = (1 << bit) - 1
                    if v & mask != ALL_CLEAR:
                        return False
                else:
                    # this is reached self.max_pos represents the last
                    # bit (most significant) of the last int
                    if v != ALL_CLEAR:
                        return False
        return True
[#else]
    def _compute_empty(self):
        last = len(self.ints) - 1
        for i, v in enumerate(self.ints):
            if i < last:
                if v != ALL_CLEAR:
                    return False
            else:
                # last int needs special handling. Only check bits
                # below max_pos
                idx, bit = divmod(self.max_pos + 1, INT_BITSIZE)
                if idx == i:
                    mask = (1 << bit) - 1
                    if v & mask != ALL_CLEAR:
                        return False
                else:
                    # this is reached self.max_pos represents the last
                    # bit (most significant) of the last int
                    if v != ALL_CLEAR:
                        return False
        return True

    @property
    def is_empty(self):
        if self._empty is None:
            self._empty = self._compute_empty()
        return self._empty
[/#if]

[#if !optimize_bitset]
    @property
    def count(self):
        result = 0

        def count_bits(n):
            c = 0
            while n:
                n &= n - 1
                c += 1
            return c

        last = len(self.ints) - 1
        for i, v in enumerate(self.ints):
            if i < last:
                result += count_bits(v)
            else:
                # last int needs special handling. Only check bits
                # below max_pos
                idx, bit = divmod(self.max_pos + 1, INT_BITSIZE)
                if idx == i:
                    mask = (1 << bit) - 1
                    result += count_bits(v & mask)
                else:
                    # this is reached self.max_pos represents the last
                    # bit (most significant) of the last int
                    result += count_bits(v)
        return result

[/#if]
    def slow_next_set_bit(self, pos):
        for i in range(pos, self.max_pos + 1):
            if self[i]:
                return i
        return -1

    def fast_next_set_bit(self, pos):
        if pos < 0 or pos > self.max_pos:
            return -1
[#if optimize_bitset]
        idx, bit = divmod(pos, INT_BITSIZE)
[#else]
        idx, bit = self._idx_and_bit(pos)
[/#if]
        mask = 1 << bit
        if self.ints[idx] & mask:
            return pos
        while True:
            v = self.ints[idx] & ~(mask - 1)  # mask off lower bits
            if v == 0:
                idx += 1
                if idx >= len(self.ints):
                    return -1
                bit = 0
                mask = 1
                continue
            # v & -v leaves only the least significant bit
            result = INT_BITSIZE * idx + BIT_POS[v & -v]
            return result

[#if optimize_bitset]
    next_set_bit = fast_next_set_bit
[#else]
    next_set_bit = slow_next_set_bit
[/#if]

    def previous_set_bit(self, pos):
        if pos < 0:
            return -1
        idx, bit = divmod(pos, INT_BITSIZE)
        mask = 1 << bit
        if self.ints[idx] & mask:
            return pos

        mask = 0 if bit == (INT_BITSIZE - 1) else ~((mask << 1) - 1)
        while True:
            v = self.ints[idx] & ~mask  # mask off higher bits
            if v == 0:
                idx -= 1
                if idx < 0:
                    return -1
                mask = 0
                continue
            result = 0
            v = v >> 1
            while v:
                result += 1
                v = v >> 1
            return result + INT_BITSIZE * idx


[#var TABS_TO_SPACES = 0, PRESERVE_LINE_ENDINGS="True", JAVA_UNICODE_ESCAPE="False", ENSURE_FINAL_EOL = grammar.ensureFinalEOL?string("True", "False")]
[#if grammar.settings.TABS_TO_SPACES??]
   [#set TABS_TO_SPACES = grammar.settings.TABS_TO_SPACES]
[/#if]
[#if grammar.settings.PRESERVE_LINE_ENDINGS?? && !grammar.settings.PRESERVE_LINE_ENDINGS]
   [#set PRESERVE_LINE_ENDINGS = "False"]
[/#if]
[#if grammar.settings.JAVA_UNICODE_ESCAPE?? && grammar.settings.JAVA_UNICODE_ESCAPE]
   [#set JAVA_UNICODE_ESCAPE = "True"]
[/#if]
class ListIterator:
    #
    # Emulation of the Java interface / implementation
    #
    __slots__ = (
        'elems',
        'num',
        'pos'
    )

    def __init__(self, alist, pos=0):
        self.elems = list(alist)
        self.num = len(alist)
        assert pos <= self.num
        self.pos = pos

    @property
    def has_next(self):
        return self.pos < self.num

    @property
    def has_previous(self):
        return self.pos > 0

    @property
    def next(self):
        assert self.has_next
        result = self.elems[self.pos]
        if self.pos < self.num:
            self.pos += 1
        return result

    @property
    def previous(self):
        assert self.has_previous
        result = self.elems[self.pos - 1]
        if self.pos > 0:
            self.pos -= 1
        return result


class StringBuilder:
    """
    Adapter class for Java StringBuilder
    """
    __slots__ = ('buf',)

    def __init__(self):
        self.buf = []

    def append(self, value):
        self.buf.append(str(value))

    def __str__(self):
        return ''.join(self.buf)


class _Set(set):
    """
    Adapter class for Java.util.HashSet
    """
    def remove(self, item):
        if item in self:
            super().remove(item)

HashSet = _Set

class _List(list):
    """
    Adapter class for Java.util.List
    """
    def __init__(self, *args):
        super().__init__()
        if args:
            arg0 = args[0]
            if isinstance(arg0, list):
                self.extend(arg0)

    def add(self, item):
        self.append(item)

    def index_of(self, item):
        try:
            return self.index(item)
        except ValueError:
            return -1

    def size(self):
        return len(self)

    def remove(self, idx):
        del self[idx]

    def add_all(self, other):
        self.extend(other)


_FROZEN_SETS = {}


def make_frozenset(*types):
    if types in _FROZEN_SETS:
        result = _FROZEN_SETS[types]
    else:
        result = frozenset(types)
        _FROZEN_SETS[types] = result
    return result


class _GenWrapper(object):
    """
    Adapter class for Python generators to Java iterators
    """
    def __init__(self, gen):
        self.gen = gen
        self._step()

    def _step(self):
        try:
            self.next_value = next(self.gen)
            self._has_next = True
        except StopIteration:
            self._has_next = False

    def has_next(self):
        return self._has_next

    def next(self):
        assert self._has_next
        rv = self.next_value
        self._step()
        return rv