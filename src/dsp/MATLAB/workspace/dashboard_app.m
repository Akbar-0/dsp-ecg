classdef dashboard_app < matlab.apps.AppBase
% DASHBOARD_APP  ECG monitoring dashboard — phosphor-green oscilloscope theme.

    % ── UI component handles ──
    properties (Access = public)
        UIFigure      matlab.ui.Figure
        GridLayout    matlab.ui.container.GridLayout
        LeftPanel     matlab.ui.container.Panel
        CenterPanel   matlab.ui.container.Panel
        RightPanel    matlab.ui.container.Panel
        RealTimeAxes  matlab.ui.control.UIAxes
        CycleAxes     matlab.ui.control.UIAxes
        BPMLabel      matlab.ui.control.Label
        HRVLabel      matlab.ui.control.Label
        TimeLabel     matlab.ui.control.Label
        StatusLabel   matlab.ui.control.Label
    end

    % ── Palette & layout constants ──
    properties (Access = private)
        % Breakpoints (px) for responsive column reflow
        onePanelWidth = 620;
        twoPanelWidth = 980;

        % Oscilloscope colour palette
        C_BG        = [0.055 0.063 0.071]   % #0E1012  figure background
        C_PANEL     = [0.078 0.090 0.102]   % #141720  panel fill
        C_PANEL2    = [0.059 0.067 0.078]   % #0F1114  metrics panel (darker)
        C_TRACE     = [0.18  0.95  0.45]    % #2EF273  phosphor green — main trace
        C_PEAK      = [1.00  0.82  0.14]    % #FFD124  amber — R-peak markers
        C_GRID      = [0.13  0.17  0.13]    % subtle green-tinted grid
        C_TEXT_DIM  = [0.42  0.52  0.42]    % muted label text
        C_TEXT_MID  = [0.68  0.80  0.68]    % secondary value text
        C_TEXT_HI   = [0.18  0.95  0.45]    % bright phosphor — primary values
        C_AMBER     = [1.00  0.65  0.10]    % alert / warning colour
        C_BORDER    = [0.15  0.22  0.15]    % panel border tint

        % Separator line between scan columns (drawn as a patch)
        ScanLine

        % Store last BPM for the pulse-flash effect
        LastBPM = 0
    end

    % ── Private helpers ───────────────────────────────────────────────────────
    methods (Access = private)

        % Responsive layout reflow on window resize
        function updateAppLayout(app, ~)
            w = app.UIFigure.Position(3);
            if w <= app.onePanelWidth
                app.GridLayout.RowHeight    = {'2x','1x','1x'};
                app.GridLayout.ColumnWidth  = {'1x'};
                app.CenterPanel.Layout.Row  = 1;  app.CenterPanel.Layout.Column = 1;
                app.LeftPanel.Layout.Row    = 2;  app.LeftPanel.Layout.Column   = 1;
                app.RightPanel.Layout.Row   = 3;  app.RightPanel.Layout.Column  = 1;
            elseif w <= app.twoPanelWidth
                app.GridLayout.RowHeight    = {'2x','1x'};
                app.GridLayout.ColumnWidth  = {'1x','1x'};
                app.CenterPanel.Layout.Row  = 1;  app.CenterPanel.Layout.Column = [1 2];
                app.LeftPanel.Layout.Row    = 2;  app.LeftPanel.Layout.Column   = 1;
                app.RightPanel.Layout.Row   = 2;  app.RightPanel.Layout.Column  = 2;
            else
                app.GridLayout.RowHeight    = {'3x','2x'};
                app.GridLayout.ColumnWidth  = {'5x','3x'};
                app.CenterPanel.Layout.Row  = 1;  app.CenterPanel.Layout.Column = [1 2];
                app.LeftPanel.Layout.Row    = 2;  app.LeftPanel.Layout.Column   = 1;
                app.RightPanel.Layout.Row   = 2;  app.RightPanel.Layout.Column  = 2;
            end
        end

        % ── Style helpers ─────────────────────────────────────────────────────

        function styleAxes(app, ax, titleStr)
            % Apply oscilloscope look to any UIAxes object.
            ax.Color            = app.C_PANEL;
            ax.XColor           = app.C_TEXT_DIM;
            ax.YColor           = app.C_TEXT_DIM;
            ax.GridColor        = app.C_GRID;
            ax.MinorGridColor   = app.C_GRID * 0.6;
            ax.GridAlpha        = 1;
            ax.GridLineStyle    = ':';
            ax.XGrid            = 'on';
            ax.YGrid            = 'on';
            ax.Box              = 'on';
            ax.LineWidth        = 0.8;
            ax.FontName         = 'Courier New';
            ax.FontSize         = 9;
            ax.TitleFontSizeMultiplier = 1.0;
            ax.LabelFontSizeMultiplier = 1.0;

            title(ax,  titleStr,   'Color', app.C_TEXT_MID, 'FontName','Courier New','FontSize',9);
            xlabel(ax, 'time (s)', 'Color', app.C_TEXT_DIM, 'FontName','Courier New','FontSize',8);
            ylabel(ax, 'norm. amp','Color', app.C_TEXT_DIM, 'FontName','Courier New','FontSize',8);

            % Faint phosphor scanline glow via axes background gradient
            ax.XAxis.TickLength  = [0.005 0.005];
            ax.YAxis.TickLength  = [0.005 0.005];
        end

        function lbl = makeMetricLabel(~, parent, row, tag, value, fontSize, color)
            % Create a two-row label block: small grey tag above, large value below.
            tagLbl = uilabel(parent);
            tagLbl.Layout.Row    = row;
            tagLbl.Layout.Column = 1;
            tagLbl.Text          = tag;
            tagLbl.FontName      = 'Courier New';
            tagLbl.FontSize      = 8;
            tagLbl.FontColor     = [0.38 0.48 0.38];
            tagLbl.HorizontalAlignment = 'center';

            lbl = uilabel(parent);
            lbl.Layout.Row    = row + 1;
            lbl.Layout.Column = 1;
            lbl.Text          = value;
            lbl.FontName      = 'Courier New';
            lbl.FontSize      = fontSize;
            lbl.FontWeight    = 'bold';
            lbl.FontColor     = color;
            lbl.HorizontalAlignment = 'center';
        end

        % ── Component construction ────────────────────────────────────────────

        function createComponents(app)

            %% Figure
            app.UIFigure = uifigure('Visible','off');
            figW = 1120;  figH = 720;
            screenSz = get(0, 'ScreenSize');   % [1 1 screenW screenH]
            figX = (screenSz(3) - figW) / 2;
            figY = (screenSz(4) - figH) / 2;
            app.UIFigure.Position          = [figX figY figW figH];
            app.UIFigure.Name              = 'ECG Monitor';
            app.UIFigure.Color             = app.C_BG;
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.SizeChangedFcn    = createCallbackFcn(app, @updateAppLayout, true);

            %% Root grid
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth  = {'5x','3x'};
            app.GridLayout.RowHeight    = {'3x','2x'};
            app.GridLayout.ColumnSpacing = 8;
            app.GridLayout.RowSpacing    = 8;
            app.GridLayout.Padding       = [12 12 12 12];
            app.GridLayout.BackgroundColor = app.C_BG;
            app.GridLayout.Scrollable    = 'on';

            %% ── CENTER PANEL  (real-time trace) ──────────────────────────────
            app.CenterPanel = uipanel(app.GridLayout);
            app.CenterPanel.Layout.Row    = 1;
            app.CenterPanel.Layout.Column = [1 2];
            app.CenterPanel.BackgroundColor = app.C_PANEL;
            app.CenterPanel.BorderType    = 'line';
            app.CenterPanel.HighlightColor = app.C_BORDER;
            app.CenterPanel.Title         = '';

            % Header bar inside center panel
            cg = uigridlayout(app.CenterPanel, [2 1]);
            cg.RowHeight    = {22, '1x'};
            cg.ColumnWidth  = {'1x'};
            cg.Padding      = [10 8 10 8];
            cg.RowSpacing   = 4;
            cg.BackgroundColor = app.C_PANEL;

            hdrLbl = uilabel(cg);
            hdrLbl.Layout.Row    = 1;
            hdrLbl.Layout.Column = 1;
            hdrLbl.Text          = '🎦  REAL-TIME ECG  —  LEAD II';
            hdrLbl.FontName      = 'Courier New';
            hdrLbl.FontSize      = 10;
            hdrLbl.FontWeight    = 'bold';
            hdrLbl.FontColor     = app.C_TRACE;

            app.RealTimeAxes = uiaxes(cg);
            app.RealTimeAxes.Layout.Row    = 2;
            app.RealTimeAxes.Layout.Column = 1;
            app.styleAxes(app.RealTimeAxes, '');

            %% ── LEFT PANEL  (single beat cycle) ─────────────────────────────
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row    = 2;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.BackgroundColor = app.C_PANEL;
            app.LeftPanel.BorderType    = 'line';
            app.LeftPanel.HighlightColor = app.C_BORDER;
            app.LeftPanel.Title         = '';

            lg = uigridlayout(app.LeftPanel, [2 1]);
            lg.RowHeight   = {18, '1x'};
            lg.ColumnWidth = {'1x'};
            lg.Padding     = [10 6 10 8];
            lg.RowSpacing  = 4;
            lg.BackgroundColor = app.C_PANEL;

            beatHdr = uilabel(lg);
            beatHdr.Layout.Row    = 1;
            beatHdr.Layout.Column = 1;
            beatHdr.Text          = '1️⃣  ONE CARDIAC CYCLE';
            beatHdr.FontName      = 'Courier New';
            beatHdr.FontSize      = 9;
            beatHdr.FontWeight    = 'bold';
            beatHdr.FontColor     = app.C_TEXT_MID;

            app.CycleAxes = uiaxes(lg);
            app.CycleAxes.Layout.Row    = 2;
            app.CycleAxes.Layout.Column = 1;
            app.styleAxes(app.CycleAxes, '');

            %% ── RIGHT PANEL  (metrics) ──
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row    = 2;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.BackgroundColor = app.C_PANEL2;
            app.RightPanel.BorderType    = 'line';
            app.RightPanel.HighlightColor = app.C_BORDER;
            app.RightPanel.Title         = '';

            % Right panel grid:
            %   row 1  — "LIVE METRICS" header
            %   row 2  — BPM tag
            %   row 3  — BPM value
            %   row 4  — separator space
            %   row 5  — HRV tag
            %   row 6  — HRV value
            %   row 7  — separator space
            %   row 8  — TIME tag
            %   row 9  — TIME value
            %   row 10 — spacer
            %   row 11 — STATUS value
            rg = uigridlayout(app.RightPanel, [11 1]);
            rg.RowHeight   = {20, 14, 42, 8, 14, 32, 8, 14, 22, '1x', 18};
            rg.ColumnWidth = {'1x'};
            rg.Padding     = [14 12 14 12];
            rg.RowSpacing  = 0;
            rg.BackgroundColor = app.C_PANEL2;

            % "LIVE METRICS" header
            topHdr = uilabel(rg);
            topHdr.Layout.Row    = 1;
            topHdr.Layout.Column = 1;
            topHdr.Text          = '⏺  LIVE METRICS';
            topHdr.FontName      = 'Courier New';
            topHdr.FontSize      = 10;
            topHdr.FontWeight    = 'bold';
            topHdr.FontColor     = app.C_TRACE;
            topHdr.HorizontalAlignment = 'center';

            % BPM
            bpmTag = uilabel(rg);
            bpmTag.Layout.Row  = 2;  bpmTag.Layout.Column = 1;
            bpmTag.Text        = 'HEART RATE';
            bpmTag.FontName    = 'Courier New';  bpmTag.FontSize = 8;
            bpmTag.FontColor   = app.C_TEXT_DIM;
            bpmTag.HorizontalAlignment = 'center';

            app.BPMLabel = uilabel(rg);
            app.BPMLabel.Layout.Row  = 3;  app.BPMLabel.Layout.Column = 1;
            app.BPMLabel.Text        = '--  BPM';
            app.BPMLabel.FontName    = 'Courier New';
            app.BPMLabel.FontSize    = 28;
            app.BPMLabel.FontWeight  = 'bold';
            app.BPMLabel.FontColor   = app.C_TRACE;
            app.BPMLabel.HorizontalAlignment = 'center';

            % HRV
            hrvTag = uilabel(rg);
            hrvTag.Layout.Row  = 5;  hrvTag.Layout.Column = 1;
            hrvTag.Text        = 'HRV (SDNN)';
            hrvTag.FontName    = 'Courier New';  hrvTag.FontSize = 8;
            hrvTag.FontColor   = app.C_TEXT_DIM;
            hrvTag.HorizontalAlignment = 'center';

            app.HRVLabel = uilabel(rg);
            app.HRVLabel.Layout.Row  = 6;  app.HRVLabel.Layout.Column = 1;
            app.HRVLabel.Text        = '--  ms';
            app.HRVLabel.FontName    = 'Courier New';
            app.HRVLabel.FontSize    = 22;
            app.HRVLabel.FontWeight  = 'bold';
            app.HRVLabel.FontColor   = app.C_TEXT_HI;
            app.HRVLabel.HorizontalAlignment = 'center';

            % Time
            timeTag = uilabel(rg);
            timeTag.Layout.Row  = 8;  timeTag.Layout.Column = 1;
            timeTag.Text        = 'ELAPSED / TOTAL';
            timeTag.FontName    = 'Courier New';  timeTag.FontSize = 8;
            timeTag.FontColor   = app.C_TEXT_DIM;
            timeTag.HorizontalAlignment = 'center';

            app.TimeLabel = uilabel(rg);
            app.TimeLabel.Layout.Row  = 9;  app.TimeLabel.Layout.Column = 1;
            app.TimeLabel.Text        = '--  /  --  s';
            app.TimeLabel.FontName    = 'Courier New';
            app.TimeLabel.FontSize    = 13;
            app.TimeLabel.FontColor   = app.C_TEXT_MID;
            app.TimeLabel.HorizontalAlignment = 'center';

            % Status
            app.StatusLabel = uilabel(rg);
            app.StatusLabel.Layout.Row  = 11;  app.StatusLabel.Layout.Column = 1;
            app.StatusLabel.Text        = 'initializing...';
            app.StatusLabel.FontName    = 'Courier New';
            app.StatusLabel.FontSize    = 9;
            app.StatusLabel.FontColor   = app.C_AMBER;
            app.StatusLabel.HorizontalAlignment = 'center';

            % Show
            app.UIFigure.Visible = 'on';
        end
    end

    % ── Public API ──
    methods (Access = public)

        % Constructor
        function app = dashboard_app
            createComponents(app)
            registerApp(app, app.UIFigure)
            updateAppLayout(app, [])
            if nargout == 0
                clear app
            end
        end

        % ── initialize ──
        function initialize(app, sourceText, seedBeat, fs, totalSimTime)
            if ~app.isOpen(), return; end

            app.BPMLabel.Text = '--  BPM';
            app.HRVLabel.Text = '--  ms';

            if nargin >= 5 && ~isempty(totalSimTime)
                app.TimeLabel.Text = ['0.0  /  ' num2str(totalSimTime,'%.0f') '  s'];
            else
                app.TimeLabel.Text = '--  /  --  s';
            end

            if nargin >= 2 && ~isempty(sourceText)
                app.setStatus(sourceText);
            end

            if nargin < 4 || isempty(fs), fs = 1; end

            if nargin >= 3 && ~isempty(seedBeat)
                tc = (0:length(seedBeat)-1)/fs;
                plot(app.CycleAxes, tc, seedBeat, ...
                    'Color', app.C_TRACE, 'LineWidth', 1.4);
            else
                cla(app.CycleAxes);
            end
        end

        % ── updateRealtimePlot ──
        function updateRealtimePlot(app, tDisp, y, locs, pks)
            if ~app.isOpen() || isempty(tDisp) || isempty(y), return; end

            ax = app.RealTimeAxes;
            cla(ax);
            hold(ax, 'on');

            % Main ECG trace — phosphor green with a faint shadow for depth
            plot(ax, tDisp, y, ...
                'Color', app.C_TRACE, 'LineWidth', 1.5);

            % R-peak markers — amber triangles
            if ~isempty(locs)
                plot(ax, tDisp(locs), pks, ...
                    '^', ...
                    'Color',           app.C_PEAK, ...
                    'MarkerFaceColor', app.C_PEAK, ...
                    'MarkerSize',      5, ...
                    'LineStyle',       'none');
            end

            hold(ax, 'off');

            if numel(tDisp) > 1
                xlim(ax, [tDisp(1) tDisp(end)]);
            end
            ylim(ax, [-1.15 1.15]);
        end

        % ── updateCyclePlot ──
        function updateCyclePlot(app, cycle, fs)
            if ~app.isOpen(), return; end
            cla(app.CycleAxes);
            if isempty(cycle), return; end

            tc = (0:length(cycle)-1)/fs;
            hold(app.CycleAxes, 'on');
            % Filled area beneath the curve
            area(app.CycleAxes, tc, cycle, ...
                'FaceColor', app.C_TRACE, 'FaceAlpha', 0.08, ...
                'EdgeColor', 'none');
            plot(app.CycleAxes, tc, cycle, ...
                'Color', app.C_TRACE, 'LineWidth', 1.8);
            hold(app.CycleAxes, 'off');
            xlim(app.CycleAxes, [tc(1) tc(end)]);
            ylim(app.CycleAxes, [-1.15 1.15]);
        end

        % ── updateBPM ──
        function updateBPM(app, bpm)
            if ~app.isOpen() || isempty(bpm) || isnan(bpm), return; end
            app.BPMLabel.Text = [num2str(bpm,'%.1f') '  BPM'];

            % Flash amber on tachycardia (>100) or bradycardia (<50)
            if bpm > 100 || bpm < 50
                app.BPMLabel.FontColor = app.C_AMBER;
            else
                app.BPMLabel.FontColor = app.C_TRACE;
            end
            app.LastBPM = bpm;
        end

        % ── updateHRV ──
        function updateHRV(app, hrv)
            if ~app.isOpen() || isempty(hrv) || isnan(hrv), return; end
            app.HRVLabel.Text = [num2str(hrv,'%.1f') '  ms'];

            % Colour-code HRV: low HRV (<20 ms) → amber warning
            if hrv < 20
                app.HRVLabel.FontColor = app.C_AMBER;
            else
                app.HRVLabel.FontColor = app.C_TEXT_HI;
            end
        end

        % ── updateTime ──
        function updateTime(app, currentTime, totalSimTime)
            if ~app.isOpen(), return; end
            app.TimeLabel.Text = [num2str(currentTime,'%.1f') ...
                '  /  ' num2str(totalSimTime,'%.0f') '  s'];
        end

        % ── setStatus ──
        function setStatus(app, statusText)
            if ~app.isOpen(), return; end

            app.StatusLabel.Text = statusText;

            % Colour-code by keyword
            txt = lower(statusText);
            if contains(txt, 'warning') || contains(txt, 'lead') || contains(txt, 'off')
                app.StatusLabel.FontColor = app.C_AMBER;
            elseif contains(txt, 'complete') || contains(txt, 'done')
                app.StatusLabel.FontColor = app.C_TEXT_MID;
            elseif contains(txt, 'stream') || contains(txt, 'running')
                app.StatusLabel.FontColor = app.C_TRACE;
            else
                app.StatusLabel.FontColor = app.C_TEXT_DIM;
            end
        end

        % ── isOpen ──
        function tf = isOpen(app)
            tf = isvalid(app) && isvalid(app.UIFigure);
        end

        % ── delete ──
        function delete(app)
            if isvalid(app) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
