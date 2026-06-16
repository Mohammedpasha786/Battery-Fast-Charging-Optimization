function saveResultsCSV(results, outFile)
% SAVERESULTSCSV  Write performance metrics for all strategies to CSV.
%
%   saveResultsCSV(results, outFile)

    [outDir,~,~] = fileparts(outFile);
    if ~isfolder(outDir), mkdir(outDir); end

    methods = fieldnames(results);
    fields  = {'chargingTime_min','chargingTime_to80pct','finalSOC','maxVoltage_V', ...
               'maxTemp_C','riseTemp_C','coulombicEfficiency','energyEfficiency', ...
               'avgCRate','maxPlatingRisk','platingRiskFlag'};
    labels  = {'Charging Time (min)','Time to 80% SOC (min)','Final SOC', ...
               'Max Voltage (V)','Max Temperature (°C)','Temp Rise (°C)', ...
               'Coulombic Efficiency','Energy Efficiency','Avg C-rate', ...
               'Max theta_neg (plating)','Plating Risk Flag'};

    fid = fopen(outFile, 'w');
    % Header
    fprintf(fid, 'Metric');
    for m = 1:numel(methods)
        fprintf(fid, ',%s', upper(methods{m}));
    end
    fprintf(fid, '\n');

    % Rows
    for f = 1:numel(fields)
        fprintf(fid, '%s', labels{f});
        for m = 1:numel(methods)
            mname = methods{m};
            val = NaN;
            if isfield(results.(mname), 'metrics') && isfield(results.(mname).metrics, fields{f})
                val = results.(mname).metrics.(fields{f});
            end
            if islogical(val)
                fprintf(fid, ',%d', double(val));
            else
                fprintf(fid, ',%.4f', val);
            end
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
    fprintf('  Results CSV saved: %s\n', outFile);
end
