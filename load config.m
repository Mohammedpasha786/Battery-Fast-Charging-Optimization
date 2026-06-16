function cfg = loadConfig(yamlFile)
% LOADCONFIG  Lightweight YAML parser for battery project configuration.
%
%   cfg = loadConfig(yamlFile)
%
%   Supports scalar values, inline lists, nested mappings, and comments.
%   Falls back to built-in readyaml() if available (MATLAB R2024a+).

    assert(isfile(yamlFile), 'Config file not found: %s', yamlFile);

    if exist('readyaml', 'file') == 2 || exist('readyaml', 'builtin') == 5
        cfg = readyaml(yamlFile);
        return;
    end

    lines = readlines(yamlFile);
    [cfg, ~] = parseBlock(lines, 1, -1);
end


function [result, nextIdx] = parseBlock(lines, startIdx, parentIndent)
    result = struct();
    i = startIdx;
    n = numel(lines);

    while i <= n
        raw  = char(lines(i));
        trim = strtrim(raw);

        if isempty(trim) || trim(1) == '#'
            i = i + 1; continue;
        end

        indent = length(raw) - length(strtrim(raw));

        if indent <= parentIndent
            nextIdx = i; return;
        end

        trim = regexprep(trim, '\s*#.*$', '');
        cIdx = find(trim == ':', 1);
        if isempty(cIdx), i = i+1; continue; end

        key   = strtrim(trim(1:cIdx-1));
        valStr= strtrim(trim(cIdx+1:end));
        fname = regexprep(key, '[^a-zA-Z0-9_]', '_');
        if ~isempty(fname) && ~isletter(fname(1)), fname = ['f_' fname]; end

        if isempty(valStr)
            [child, i] = parseBlock(lines, i+1, indent);
            result.(fname) = child;
        else
            result.(fname) = parseVal(valStr);
            i = i + 1;
        end
    end
    nextIdx = i;
end


function v = parseVal(s)
    s = strtrim(s);
    if (startsWith(s,'"')&&endsWith(s,'"')) || (startsWith(s,"'")&&endsWith(s,"'"))
        v = s(2:end-1); return;
    end
    if startsWith(s,'[') && endsWith(s,']')
        inner = s(2:end-1);
        if isempty(strtrim(inner)), v = []; return; end
        items = strtrim(strsplit(inner, ','));
        nums  = str2double(items);
        if all(~isnan(nums)), v = nums; else, v = items; end
        return;
    end
    if strcmpi(s,'true'),  v = true;  return; end
    if strcmpi(s,'false'), v = false; return; end
    num = str2double(s);
    if ~isnan(num), v = num; else, v = s; end
end
