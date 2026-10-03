% =========================================================================
% fir4_gen_vectors.m -- Generate stimulus + expected output hex files
%
%   vec = fir4_gen_vectors()          writes to ../tb
%   vec = fir4_gen_vectors(out_dir)   writes to out_dir
%
%   Writes tb/stim_vectors.hex     (8-bit signed, 2 hex digits/line)
%          tb/expected_vectors.hex (11-bit signed, 3 hex digits/line)
%   Returns struct with x, y, pattern names and 1-based start/stop indices.
% =========================================================================
function vec = fir4_gen_vectors(varargin)
    if nargin >= 1
        out_dir = varargin{1};
    else
        out_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'tb');
    end
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    XMAX = 127;  XMIN = -128;
    rng(572, 'twister');               % fixed seed: same vectors every run

    % ---- 8 test patterns {name, samples}. Lengths total 716. ----
    pats = {
        'impulse',   [XMAX; zeros(15,1)]             % 16: output = taps
        'step',      XMAX * ones(32,1)               % 32: DC gain = 1
        'ramp',      (XMIN:XMAX)'                    % 256: every input code once
        'sin_low',   tone(64, 1/32, XMAX)            % 64: passes almost unchanged
        'sin_high',  tone(64, 0.45, XMAX)            % 64: near Nyquist, crushed
        'chirp',     sweep(128, XMAX)                % 128: DC -> Nyquist
        'random',    randi([XMIN XMAX], 128, 1)      % 128: random bit patterns
        'sat',       sat_corners(XMAX, XMIN)         % 28: accumulator extremes
    };

    names = pats(:,1);
    x = vertcat(pats{:,2});
    x = min(max(x, XMIN), XMAX);       % guard against rounding past range

    y = fir4_golden(x);                % RTL-equivalent expected outputs

    write_hex(fullfile(out_dir, 'stim_vectors.hex'),     x, 8);
    write_hex(fullfile(out_dir, 'expected_vectors.hex'), y, 11);

    % Index map: trace a TB mismatch back to its pattern (0-based, like the TB)
    lens  = cellfun(@numel, pats(:,2));
    stop  = cumsum(lens);
    start = stop - lens + 1;
    fprintf('Wrote %d vectors to %s\n', numel(x), out_dir);
    for k = 1:numel(names)
        fprintf('  %-9s vectors %4d - %4d\n', names{k}, start(k)-1, stop(k)-1);
    end

    vec = struct('x', x, 'y', y, 'names', {names}, 'start', start, 'stop', stop);
end

% Sine at f cycles/sample, rounded to integers
function x = tone(N, f, A)
    n = (0:N-1)';
    x = round(A * sin(2*pi*f*n));
end

% Linear chirp sweeping 0 -> 0.5 cycles/sample (Nyquist) over N samples
function x = sweep(N, A)
    n = (0:N-1)';
    x = round(A * cos(pi * 0.5 * n.^2 / (N-1)));
end

% All taps are positive, so all-max / all-min hit the accumulator extremes:
%   8 * 127 = 1016 -> y = 127      8 * (-128) = -1024 -> y = -128
function x = sat_corners(XMAX, XMIN)
    x = [repmat(XMAX, 8, 1);           % hold max positive
         repmat(XMIN, 8, 1);           % full-scale jump to max negative
         repmat([XMAX; XMIN], 6, 1)];  % swing every sample
end

% Two's complement hex, one value per line (for $readmemh)
function write_hex(fname, v, bits)
    u   = mod(round(v), 2^bits);
    fid = fopen(fname, 'w');
    assert(fid > 0, 'Cannot open %s', fname);
    fprintf(fid, ['%0' num2str(ceil(bits/4)) 'X\n'], u);
    fclose(fid);
end
