% =========================================================================
% fir4_visualize.m -- 6 figures for the fir4 write-up
%
%   fir4_visualize()      regenerates vectors, then plots
%   fir4_visualize(vec)   uses the struct returned by fir4_gen_vectors
%
%   Saves PNGs to matlab/figures/. Uses only base MATLAB (no toolboxes),
%   so it runs headless on volta with matlab -batch.
% =========================================================================
function fir4_visualize(vec)
    if nargin < 1, vec = fir4_gen_vectors(); end
    H = [1 3 3 1] / 8;

    fig_dir = fullfile(fileparts(mfilename('fullpath')), 'figures');
    if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

    % ---- 1. Frequency response ----
    nfft = 1024;
    Hf = fft(H, 2*nfft);   Hf = Hf(1:nfft).';
    w  = (0:nfft-1)' / nfft;                  % x pi rad/sample
    magdB = 20*log10(abs(Hf) + eps);
    w3 = w(find(magdB <= -3, 1));

    f = new_fig();
    subplot(2,1,1);
    plot(w, magdB, 'LineWidth', 1.5); hold on; grid on;
    plot([w3 w3], [-60 5], 'r--');
    ylim([-60 5]); ylabel('Magnitude (dB)');
    title(sprintf('fir4 frequency response  (-3 dB at %.3f\\pi rad/sample)', w3));
    subplot(2,1,2);
    plot(w, unwrap(angle(Hf)), 'LineWidth', 1.5); grid on;
    xlabel('Normalized frequency (\times\pi rad/sample)'); ylabel('Phase (rad)');
    title('Linear phase: group delay = 1.5 samples');
    save_fig(f, fig_dir, '1_freq_response');

    % ---- 2. Pole-zero plot ----
    z  = roots(H * 8);                        % (z+1)^3: triple zero at -1
    th = linspace(0, 2*pi, 256);
    f = new_fig();
    plot(cos(th), sin(th), 'k:'); hold on; grid on; axis equal;
    plot(real(z), imag(z), 'bo', 'MarkerSize', 12, 'LineWidth', 1.5);
    plot(0, 0, 'rx', 'MarkerSize', 12, 'LineWidth', 1.5);
    text(-1.05, 0.18, '3', 'FontSize', 12);
    text(0.05, 0.18, '3', 'FontSize', 12);
    xlim([-1.5 1.5]); ylim([-1.5 1.5]);
    xlabel('Real'); ylabel('Imaginary');
    title('Pole-zero: 3 zeros at z = -1, 3 poles at z = 0 (always stable)');
    save_fig(f, fig_dir, '2_pole_zero');

    % ---- 3. Impulse response: exact vs RTL ----
    [yr, ye] = fir4_golden([127; zeros(7,1)]);
    f = new_fig();
    stem(0:7, ye, 'filled', 'LineWidth', 1.5); hold on; grid on;
    stem(0:7, yr, 'LineWidth', 1.5);
    legend('Exact (127 \times h/8)', 'RTL (floor)');
    xlabel('Sample n'); ylabel('y[n]');
    title('Impulse response (input = 127 at n = 0)');
    save_fig(f, fig_dir, '3_impulse');

    % ---- 4. Chirp response (long chirp for a clean plot) ----
    Nc = 1024;
    n  = (0:Nc-1)';
    xc = round(127 * cos(pi * 0.5 * n.^2 / (Nc-1)));
    yc = fir4_golden(xc);
    finst = n / (Nc-1);                       % instantaneous freq, x pi
    env   = 127 * abs(fft(H, 2*Nc)); env = env(1:Nc);
    f = new_fig();
    plot(finst, xc, 'Color', [0.7 0.7 0.7]); hold on; grid on;
    plot(finst, yc, 'b');
    plot(finst, env, 'r--', 'LineWidth', 1.5);
    legend('Input', 'RTL output', '127 \times |H(f)|');
    xlabel('Instantaneous frequency (\times\pi rad/sample)'); ylabel('Amplitude');
    title('Chirp: output shrinks as frequency rises (low-pass)');
    save_fig(f, fig_dir, '4_chirp');

    % ---- 5. Spectrogram of chirp, input vs output ----
    [Sx, fq, t] = stft_db(xc, 64, 8, 256);
    Sy          = stft_db(yc, 64, 8, 256);
    f = new_fig();
    subplot(1,2,1); imagesc(t, fq*2, Sx); axis xy; caxis([-20 60]); colorbar;
    xlabel('Sample'); ylabel('Frequency (\times\pi rad/sample)'); title('Input');
    subplot(1,2,2); imagesc(t, fq*2, Sy); axis xy; caxis([-20 60]); colorbar;
    xlabel('Sample'); title('Output');
    save_fig(f, fig_dir, '5_spectrogram');

    % ---- 6. Quantization error over the full test stream ----
    [yr, ye] = fir4_golden(vec.x);
    e = ye - yr;                              % floor => always in [0, 1)
    f = new_fig();
    subplot(2,1,1);
    plot(0:numel(e)-1, e, '.'); hold on; grid on;
    for k = 2:numel(vec.start)
        plot([vec.start(k) vec.start(k)] - 1, [0 1], 'k:');
    end
    ylim([-0.05 1]); xlabel('Vector index'); ylabel('Exact - RTL');
    title(sprintf('Quantization error (mean %.3f LSB, max %.3f LSB)', mean(e), max(e)));
    subplot(2,1,2);
    levels = (0:7) / 8;
    counts = arrayfun(@(L) sum(abs(e - L) < 1e-9), levels);
    bar(levels, counts); grid on;
    xlabel('Error (LSB)'); ylabel('Count');
    title('Error only takes values k/8: the 3 bits dropped by >>> 3');
    save_fig(f, fig_dir, '6_quant_error');

    fprintf('Saved 6 figures to %s\n', fig_dir);
end

% Short-time FFT magnitude in dB (Hann window), base MATLAB only
function [S, f, t] = stft_db(x, win, hop, nfft)
    w = 0.5 - 0.5*cos(2*pi*(0:win-1)'/(win-1));
    starts = 1:hop:numel(x)-win+1;
    S = zeros(nfft/2+1, numel(starts));
    for k = 1:numel(starts)
        X = fft(x(starts(k):starts(k)+win-1) .* w, nfft);
        S(:,k) = 20*log10(abs(X(1:nfft/2+1)) + eps);
    end
    f = (0:nfft/2)' / nfft;                   % cycles/sample
    t = starts + win/2 - 1;
end

function f = new_fig()
    f = figure('Visible', 'off', 'Position', [100 100 900 600]);
end

function save_fig(f, fig_dir, name)
    print(f, fullfile(fig_dir, [name '.png']), '-dpng', '-r150');
    close(f);
end
