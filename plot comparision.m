function plotComparison(results, chrgParams, outDir)
% PLOTCOMPARISON  Generate a 4-panel comparison plot of all charging strategies.
%
%   Panel 1: Current vs time
%   Panel 2: Voltage vs time
%   Panel 3: SOC vs time
%   Panel 4: Temperature vs time (if available)
%
%   plotComparison(results, chrgParams, outDir)

    methods = fieldnames(results);
    nM      = numel(methods);
    cmap    = lines(nM);

    labels  = struct('cccv','CC-CV','multistage','Multi-Stage CC', ...
                     'mpc','MPC','pseudospectral','Pseudo-spectral','collocation','Collocation');

    fig = figure('Name','Charging Strategy Comparison', ...
                 'Position',[100 100 1200 850], 'Visible','off');

    titles  = {'Charging Current (A)', 'Terminal Voltage (V)', ...
               'State of Charge (%)', 'Temperature (°C)'};
    ylabels = {'Current (A)', 'Voltage (V)', 'SOC (%)', 'Temperature (°C)'};

    for panel = 1:4
        ax = subplot(2,2,panel);
        hold(ax,'on');

        for m = 1:nM
            mname = methods{m};
            out   = results.(mname);
            t_min = out.time / 60;

            label = mname;
            if isfield(labels, mname), label = labels.(mname); end
            if isfield(out, 'metrics')
                label = sprintf('%s (%.1f min)', label, out.metrics.chargingTime_min);
            end

            switch panel
                case 1
                    plot(ax, t_min, out.current, 'LineWidth', 1.8, ...
                         'Color', cmap(m,:), 'DisplayName', label);
                case 2
                    plot(ax, t_min, out.voltage, 'LineWidth', 1.8, ...
                         'Color', cmap(m,:), 'DisplayName', label);
                    yline(ax, chrgParams.voltage_max_V, 'k--', ...
                          'LineWidth', 1.2, 'HandleVisibility', 'off');
                case 3
                    plot(ax, t_min, out.soc * 100, 'LineWidth', 1.8, ...
                         'Color', cmap(m,:), 'DisplayName', label);
                    yline(ax, chrgParams.soc_target * 100, 'k--', ...
                          'LineWidth', 1.2, 'HandleVisibility', 'off');
                case 4
                    plot(ax, t_min, out.temperature - 273.15, 'LineWidth', 1.8, ...
                         'Color', cmap(m,:), 'DisplayName', label);
                    if isfield(chrgParams, 'T_max_C')
                        yline(ax, chrgParams.T_max_C, 'r--', ...
                              'LineWidth', 1.2, 'HandleVisibility', 'off');
                    end
            end
        end

        xlabel(ax, 'Time (min)', 'FontSize', 10);
        ylabel(ax, ylabels{panel}, 'FontSize', 10);
        title(ax, titles{panel}, 'FontSize', 11, 'FontWeight', 'bold');
        legend(ax, 'Location', 'best', 'FontSize', 8);
        grid(ax, 'on');
    end

    sgtitle('Li-ion Battery Charging Strategy Comparison', ...
            'FontSize', 13, 'FontWeight', 'bold');

    %% ── Bar chart: metrics summary ──────────────────────────────────────
    if nM > 0
        figure('Name','Metrics Summary','Position',[150 150 900 400],'Visible','off');
        metricNames = {'chargingTime_min','maxTemp_C','maxPlatingRisk','coulombicEfficiency'};
        metricLabels= {'Charge Time (min)','Max Temp (°C)','Max θ_neg','Coulombic Eff.'};
        barData = zeros(nM, numel(metricNames));
        mLabels = cell(nM,1);
        for m = 1:nM
            mname = methods{m};
            if isfield(labels, mname), mLabels{m} = labels.(mname);
            else mLabels{m} = mname; end
            for f = 1:numel(metricNames)
                if isfield(results.(mname).metrics, metricNames{f})
                    barData(m,f) = results.(mname).metrics.(metricNames{f});
                end
            end
        end
        for f = 1:numel(metricNames)
            ax_b = subplot(1, numel(metricNames), f);
            bar(ax_b, barData(:,f), 'FaceColor', 'flat', 'CData', cmap(1:nM,:));
            set(ax_b, 'XTickLabel', mLabels, 'XTick', 1:nM, 'FontSize', 8);
            title(ax_b, metricLabels{f}, 'FontSize', 10);
            xtickangle(ax_b, 30);
            grid(ax_b, 'on');
        end
        sgtitle('Performance Metrics Summary', 'FontSize', 12, 'FontWeight', 'bold');
        saveas(gcf, fullfile(outDir, 'plots', 'metrics_summary.png'));
        close(gcf);
    end

    %% ── Save main comparison ─────────────────────────────────────────────
    if ~isfolder(fullfile(outDir,'plots')), mkdir(fullfile(outDir,'plots')); end
    saveas(fig, fullfile(outDir, 'plots', 'comparison_all_profiles.png'));
    fprintf('  Comparison plot saved: %s\n', fullfile(outDir,'plots','comparison_all_profiles.png'));
    close(fig);
end
