% =========================================================================
% fir4_golden.m -- Golden models for the 4-tap symmetric FIR [1 3 3 1]/8
%
%   [y_rtl, y_exact, dbg] = fir4_golden(x)
%
%   x       : input samples, 8-bit signed integers (-128..127)
%   y_rtl   : bit-accurate hardware model, floor((sum_a + prod_b)/8)
%   y_exact : ideal model, filter([1 3 3 1]/8, 1, x)
%   dbg     : intermediate datapath values (sum_a, sum_b, prod_b, acc)
%
% Hardware datapath (uses coefficient symmetry, c0 = c3 and c1 = c2):
%   sum_a  = x[n]   + x[n-3]        9-bit signed   (taps of weight 1)
%   sum_b  = x[n-1] + x[n-2]        9-bit signed   (taps of weight 3)
%   prod_b = 3 * sum_b              11-bit signed
%   y      = (sum_a + prod_b) >>> 3 8-bit signed, sign-extended to 11 bits
% =========================================================================
function [y_rtl, y_exact, dbg] = fir4_golden(x)
    H    = [1 3 3 1];
    NORM = 3;

    x = double(x(:));
    assert(all(x == round(x)) && all(x >= -128 & x <= 127), ...
        'fir4_golden: x must be 8-bit signed integers');

    % ---- Exact model: ideal math, keeps the fractions ----
    y_exact = filter(H, 1, x) / 2^NORM;

    % ---- RTL model: same datapath as rtl/fir4.sv ----
    xd = [zeros(3,1); x];              % delay line, reset to 0
    k  = (4:numel(xd))';
    x0 = xd(k);    x1 = xd(k-1);    x2 = xd(k-2);    x3 = xd(k-3);

    sum_a  = x0 + x3;
    sum_b  = x1 + x2;
    prod_b = 3 * sum_b;
    acc    = sum_a + prod_b;
    y_rtl  = floor(acc / 2^NORM);      % floor == arithmetic >>> 3

    % ---- Bit-width checks: every value must fit its register ----
    check_width(sum_a,  9,  'sum_a');
    check_width(sum_b,  9,  'sum_b');
    check_width(prod_b, 11, 'prod_b');
    check_width(y_rtl,  8,  'y');

    dbg = struct('sum_a', sum_a, 'sum_b', sum_b, 'prod_b', prod_b, 'acc', acc);
end

function check_width(v, bits, name)
    lo = -2^(bits-1);
    hi =  2^(bits-1) - 1;
    assert(all(v >= lo & v <= hi), ...
        'fir4_golden: %s exceeds %d-bit signed range [%d, %d]', name, bits, lo, hi);
end
