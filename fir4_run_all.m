% =========================================================================
% fir4_run_all.m -- Entry point for the MATLAB stage
%
%   matlab -batch "fir4_run_all"
%
%   1. Self-checks on the golden model (fails fast with a clear message)
%   2. Generate tb/stim_vectors.hex + tb/expected_vectors.hex
%   3. Generate the 6 figures in matlab/figures/
%   Any failed assert exits non-zero, so run_flow.sh sees the failure.
% =========================================================================
function fir4_run_all()
    addpath(fileparts(mfilename('fullpath')));
    fprintf('=== fir4 MATLAB flow ===\n');

    self_check();
    vec = fir4_gen_vectors();
    fir4_visualize(vec);

    fprintf('=== MATLAB flow PASSED ===\n');
end

function self_check()
    % Impulse: output must be floor(127 * [1 3 3 1] / 8)
    y = fir4_golden([127; zeros(4,1)]);
    assert(isequal(y(:)', [15 47 47 15 0]), 'Impulse response mismatch');

    % DC gain = 1 once the delay line fills (3 samples in)
    y = fir4_golden(100 * ones(8,1));
    assert(all(y(4:end) == 100), 'DC gain mismatch');

    % Rounding must match >>> 3: floor(-9/8) = -2, not -1
    y = fir4_golden([-9; 0; 0; 0]);
    assert(y(1) == -2, 'Negative rounding mismatch (use floor, not round/fix)');

    % RTL vs exact: floor error is always in [0, 1) LSB
    rng(1);
    [yr, ye] = fir4_golden(randi([-128 127], 5000, 1));
    e = ye - yr;
    assert(all(e >= 0 & e < 1), 'RTL model drifted from exact model');

    fprintf('Self-checks passed (4/4)\n');
end
