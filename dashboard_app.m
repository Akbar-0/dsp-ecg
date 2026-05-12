function app = dashboard_app()
% DASHBOARD_APP  Octave-compatible ECG dashboard.
% Must be saved as its own file: dashboard_app.m

    %% ── Palette ──────────────────────────────────────────────────────────────
    C_BG    = [0.055 0.063 0.071];
    C_PANEL = [0.078 0.090 0.102];
    C_TRACE = [0.18  0.95  0.45 ];
    C_PEAK  = [1.00  0.82  0.14 ];
    C_GRID  = [0.13  0.17  0.13 ];
    C_DIM   = [0.42  0.52  0.42 ];
    C_MID   = [0.68  0.80  0.68 ];
    C_AMBER = [1.00  0.65  0.10 ];

    %% ── Figure ───────────────────────────────────────────────────────────────
    scr  = get(0, 'ScreenSize');
    figW = 1120; figH = 720;
    figX = (scr(3) - figW) / 2;
    figY = (scr(4) - figH) / 2;

    hFig = figure( ...
        'Name',        'ECG Monitor', ...
        'NumberTitle', 'off', ...
        'Color',       C_BG, ...
        'Position',    [figX figY figW figH], ...
        'MenuBar',     'none', ...
        'Toolbar',     'none', ...
        'Resize',      'on');

    figNum = get(hFig, 'Number');

    %% ── Axes ─────────────────────────────────────────────────────────────────

    % Real-time trace (top, slightly shorter to make room below)
    axRT = axes('Parent', hFig, ...
        'Position',      [0.04 0.42 0.92 0.50], ...
        'Color',         C_PANEL, ...
        'XColor',        C_DIM,  'YColor',    C_DIM, ...
        'GridColor',     C_GRID, 'GridAlpha', 1, ...
        'XGrid', 'on',   'YGrid', 'on', ...
        'GridLineStyle', ':', ...
        'Box',           'on',   'LineWidth', 0.8, ...
        'FontName', 'Courier New', 'FontSize', 8);
    xlabel(axRT, 'time (s)',   'Color', C_DIM, 'FontName', 'Courier New', 'FontSize', 8);
    ylabel(axRT, 'norm. amp', 'Color', C_DIM, 'FontName', 'Courier New', 'FontSize', 8);
    title( axRT, '[ REAL-TIME ECG  -  LEAD II ]', ...
        'Color', C_TRACE, 'FontName', 'Courier New', 'FontSize', 9, 'FontWeight', 'bold');

    % Single cardiac cycle (bottom-left third)
    axCY = axes('Parent', hFig, ...
        'Position',      [0.04 0.06 0.34 0.30], ...
        'Color',         C_PANEL, ...
        'XColor',        C_DIM,  'YColor',    C_DIM, ...
        'GridColor',     C_GRID, 'GridAlpha', 1, ...
        'XGrid', 'on',   'YGrid', 'on', ...
        'GridLineStyle', ':', ...
        'Box',           'on',   'LineWidth', 0.8, ...
        'FontName', 'Courier New', 'FontSize', 8);
    xlabel(axCY, 'time (s)',   'Color', C_DIM, 'FontName', 'Courier New', 'FontSize', 8);
    ylabel(axCY, 'norm. amp', 'Color', C_DIM, 'FontName', 'Courier New', 'FontSize', 8);
    title( axCY, '[ ONE CARDIAC CYCLE ]', ...
        'Color', C_MID, 'FontName', 'Courier New', 'FontSize', 9, 'FontWeight', 'bold');

    % Power spectrum / FFT (bottom-right two-thirds)
    axFFT = axes('Parent', hFig, ...
        'Position',      [0.42 0.06 0.54 0.30], ...
        'Color',         C_PANEL, ...
        'XColor',        C_DIM,  'YColor',    C_DIM, ...
        'GridColor',     C_GRID, 'GridAlpha', 1, ...
        'XGrid', 'on',   'YGrid', 'on', ...
        'GridLineStyle', ':', ...
        'Box',           'on',   'LineWidth', 0.8, ...
        'FontName', 'Courier New', 'FontSize', 8);
    xlabel(axFFT, 'frequency (Hz)', 'Color', C_DIM, 'FontName', 'Courier New', 'FontSize', 8);
    ylabel(axFFT, 'power (dB)',     'Color', C_DIM, 'FontName', 'Courier New', 'FontSize', 8);
    title( axFFT, '[ POWER SPECTRUM  -  DISPLAY WINDOW ]', ...
        'Color', C_MID, 'FontName', 'Courier New', 'FontSize', 9, 'FontWeight', 'bold');

    %% ── Metrics text labels ───────────────────────────────────────────────────
    _mtxt(hFig, '[ LIVE METRICS ]', 0.64, 0.33, 0.33, 0.030,  9, C_TRACE, true,  C_BG);
    _mtxt(hFig, 'HEART RATE',       0.64, 0.29, 0.33, 0.025,  7, C_DIM,   false, C_BG);
    _mtxt(hFig, 'HRV (SDNN)',       0.64, 0.20, 0.33, 0.025,  7, C_DIM,   false, C_BG);
    _mtxt(hFig, 'ELAPSED / TOTAL',  0.64, 0.13, 0.33, 0.025,  7, C_DIM,   false, C_BG);

    hBPM    = _mtxt(hFig, '--  BPM',        0.64, 0.23,  0.33, 0.050, 18, C_TRACE, true,  C_BG);
    hHRV    = _mtxt(hFig, '--  ms',         0.64, 0.155, 0.33, 0.040, 14, C_TRACE, true,  C_BG);
    hTime   = _mtxt(hFig, '--  /  --  s',   0.64, 0.09,  0.33, 0.030, 10, C_MID,   false, C_BG);
    hStatus = _mtxt(hFig, 'initializing...', 0.64, 0.06, 0.33, 0.030,  8, C_AMBER, false, C_BG);

    drawnow;

    %% ── API struct ───────────────────────────────────────────────────────────
    app = struct();
    app.isOpen             = @()      _isOpen(figNum);
    app.delete             = @()      _delete(figNum);
    app.initialize         = @(varargin) _initialize(figNum, axCY, hBPM, hHRV, hTime, hStatus, C_TRACE, C_DIM, C_AMBER, C_MID, varargin{:});
    app.updateRealtimePlot = @(varargin) _updateRealtimePlot(figNum, axRT, C_TRACE, C_PEAK, varargin{:});
    app.updateCyclePlot    = @(varargin) _updateCyclePlot(figNum, axCY, C_TRACE, C_PEAK, varargin{:});
    app.updateFFT          = @(varargin) _updateFFT(figNum, axFFT, C_TRACE, C_AMBER, C_PEAK, varargin{:});
    app.updateBPM          = @(varargin) _updateBPM(figNum, hBPM, C_TRACE, C_AMBER, varargin{:});
    app.updateHRV          = @(varargin) _updateHRV(figNum, hHRV, C_TRACE, C_AMBER, varargin{:});
    app.updateTime         = @(varargin) _updateTime(figNum, hTime, varargin{:});
    app.setStatus          = @(varargin) _setStatus(figNum, hStatus, C_TRACE, C_MID, C_DIM, C_AMBER, varargin{:});
end

%% ════════════════════════════════════════════════════════════════════════════
%%  File-level subfunctions
%% ════════════════════════════════════════════════════════════════════════════

function h = _mtxt(hFig, str, x, y, w, ht, sz, clr, bold, bg)
    fw = 'normal';
    if bold, fw = 'bold'; end
    h = uicontrol(hFig, ...
        'Style',               'text', ...
        'String',              str, ...
        'Units',               'normalized', ...
        'Position',            [x y w ht], ...
        'BackgroundColor',     bg, ...
        'ForegroundColor',     clr, ...
        'FontName',            'Courier New', ...
        'FontSize',            sz, ...
        'FontWeight',          fw, ...
        'HorizontalAlignment', 'center');
end

function tf = _isOpen(figNum)
    tf = ~isempty(get(0, 'Children')) && any(get(0, 'Children') == figNum);
end

function _delete(figNum)
    if _isOpen(figNum)
        close(figNum);
    end
end

function _initialize(figNum, axCY, hBPM, hHRV, hTime, hStatus, C_TRACE, C_DIM, C_AMBER, C_MID, sourceText, ~, fs, totalSimTime)
    if ~_isOpen(figNum), return; end
    set(hBPM,    'String', '--  BPM',    'ForegroundColor', C_TRACE);
    set(hHRV,    'String', '--  ms',     'ForegroundColor', C_TRACE);
    if nargin >= 14 && ~isempty(totalSimTime)
        set(hTime, 'String', ['0.0  /  ' num2str(totalSimTime, '%.0f') '  s']);
    end
    if nargin >= 11 && ~isempty(sourceText)
        _setStatus(figNum, hStatus, C_TRACE, C_MID, C_DIM, C_AMBER, sourceText);
    end
    cla(axCY);
end

function _updateRealtimePlot(figNum, axRT, C_TRACE, C_PEAK, tDisp, y, locs, pks)
    if ~_isOpen(figNum) || isempty(tDisp) || isempty(y), return; end
    cla(axRT);
    hold(axRT, 'on');
    plot(axRT, tDisp, y, 'Color', C_TRACE, 'LineWidth', 1.4);
    if ~isempty(locs)
        plot(axRT, tDisp(locs), pks, '^', ...
            'Color', C_PEAK, 'MarkerFaceColor', C_PEAK, ...
            'MarkerSize', 5, 'LineStyle', 'none');
    end
    hold(axRT, 'off');
    if numel(tDisp) > 1
        xlim(axRT, [tDisp(1) tDisp(end)]);
    end
    ylim(axRT, [-1.15 1.15]);
end

function _updateCyclePlot(figNum, axCY, C_TRACE, C_PEAK, cycle, fs)
    if ~_isOpen(figNum) || isempty(cycle), return; end
    tc = (0:length(cycle)-1) / fs;

    % Centre the time axis on the R-peak (global maximum)
    [rAmp, rIdx] = max(cycle);
    tOffset = tc(rIdx);
    tc = tc - tOffset;    % R-peak now sits at t = 0

    cla(axCY);
    hold(axCY, 'on');
    area(axCY, tc, cycle, 'FaceColor', C_TRACE, 'FaceAlpha', 0.08, 'EdgeColor', 'none');
    plot(axCY, tc, cycle, 'Color', C_TRACE, 'LineWidth', 1.8);

    % R-peak marker at t = 0
    plot(axCY, 0, rAmp, '^', ...
        'Color', C_PEAK, 'MarkerFaceColor', C_PEAK, ...
        'MarkerSize', 7, 'LineStyle', 'none');
    text(axCY, 0, rAmp + 0.12, 'R', ...
        'Color', C_PEAK, 'FontName', 'Courier New', ...
        'FontSize', 8, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % Vertical reference line at R
    line(axCY, [0 0], [-1.15 rAmp - 0.05], ...
        'Color', [0.35 0.29 0.05], 'LineStyle', '--', 'LineWidth', 0.6);

    hold(axCY, 'off');
    xlim(axCY, [tc(1) tc(end)]);
    ylim(axCY, [-1.15 1.15]);
    xlabel(axCY, 'time re R-peak (s)', 'Color', [0.42 0.52 0.42], ...
        'FontName', 'Courier New', 'FontSize', 8);
end

function _updateFFT(figNum, axFFT, C_TRACE, C_AMBER, C_PEAK, y, fs)
    if ~_isOpen(figNum) || isempty(y) || numel(y) < 16, return; end

    N   = length(y);
    win = hanning(N).';
    Y   = fft(y .* win);
    P   = (2 / (N * sum(win.^2))) * abs(Y(1:floor(N/2)+1)).^2;
    P   = 10 * log10(P + eps);                 % convert to dB
    f   = linspace(0, fs/2, floor(N/2)+1);

    cla(axFFT);
    hold(axFFT, 'on');

    % Teal shading: bandpass region used by preprocess_ecg (0.5–15 Hz)
    fMax = min(60, fs/2);
    yLo  = max(P) - 60;
    yHi  = max(P) + 6;
    patch(axFFT, [0.5 15 15 0.5], [yLo yLo yHi yHi], ...
          C_TRACE, 'FaceAlpha', 0.06, 'EdgeColor', 'none');
    text(axFFT, 7.75, yHi - 1, 'bandpass', ...
         'Color', [0.11 0.57 0.27], 'FontName', 'Courier New', 'FontSize', 7, ...
         'HorizontalAlignment', 'center');

    % Yellow shading: QRS detection band (8–22 Hz)
    patch(axFFT, [8 22 22 8], [yLo yLo yHi yHi], ...
          C_PEAK, 'FaceAlpha', 0.07, 'EdgeColor', 'none');
    text(axFFT, 15, yHi - 1, 'QRS', ...
         'Color', [0.80 0.66 0.11], 'FontName', 'Courier New', 'FontSize', 7, ...
         'HorizontalAlignment', 'center');

    % Spectrum trace
    plot(axFFT, f, P, 'Color', C_TRACE, 'LineWidth', 1.2);

    % Highlight peaks above noise floor (median + 6 dB)
    noiseFloor = median(P) + 6;
    pkMask = P > noiseFloor;
    if any(pkMask)
        plot(axFFT, f(pkMask), P(pkMask), '.', 'Color', C_AMBER, 'MarkerSize', 5);
    end

    hold(axFFT, 'off');
    xlim(axFFT, [0 fMax]);
    ylim(axFFT, [yLo yHi]);
    grid(axFFT, 'on');
end

function _updateBPM(figNum, hBPM, C_TRACE, C_AMBER, bpm)
    if ~_isOpen(figNum) || isempty(bpm) || isnan(bpm), return; end
    set(hBPM, 'String', [num2str(bpm, '%.1f') '  BPM']);
    if bpm > 100 || bpm < 50
        set(hBPM, 'ForegroundColor', C_AMBER);
    else
        set(hBPM, 'ForegroundColor', C_TRACE);
    end
end

function _updateHRV(figNum, hHRV, C_TRACE, C_AMBER, hrv)
    if ~_isOpen(figNum) || isempty(hrv) || isnan(hrv), return; end
    set(hHRV, 'String', [num2str(hrv, '%.1f') '  ms']);
    if hrv < 20
        set(hHRV, 'ForegroundColor', C_AMBER);
    else
        set(hHRV, 'ForegroundColor', C_TRACE);
    end
end

function _updateTime(figNum, hTime, currentTime, totalSimTime)
    if ~_isOpen(figNum), return; end
    set(hTime, 'String', ...
        [num2str(currentTime, '%.1f') '  /  ' num2str(totalSimTime, '%.0f') '  s']);
end

function _setStatus(figNum, hStatus, C_TRACE, C_MID, C_DIM, C_AMBER, statusText)
    if ~_isOpen(figNum), return; end
    set(hStatus, 'String', statusText);
    lo = lower(statusText);
    if ~isempty(strfind(lo, 'warning')) || ~isempty(strfind(lo, 'lead')) || ~isempty(strfind(lo, 'off'))
        set(hStatus, 'ForegroundColor', C_AMBER);
    elseif ~isempty(strfind(lo, 'stream')) || ~isempty(strfind(lo, 'running'))
        set(hStatus, 'ForegroundColor', C_TRACE);
    elseif ~isempty(strfind(lo, 'complete')) || ~isempty(strfind(lo, 'done')) || ~isempty(strfind(lo, 'ended'))
        set(hStatus, 'ForegroundColor', C_MID);
    else
        set(hStatus, 'ForegroundColor', C_DIM);
    end
end
