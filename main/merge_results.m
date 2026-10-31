%% MERGE_RESULTS  Join sweep results from several runs into one `results` struct.
%
% Use when a frequency sweep was split over several runs (for example,
% to keep each Simulink session short).
%
% Edit run_names below to list the `results` structs from each run,
% load them into the workspace, then run this script.
%
% Steps:
%   1. Concatenate every per-frequency field (row vectors and the 7xN
%      breakdown matrix) in run order.
%   2. Remove points with freq == 0 (simulation crashed or was skipped).
%   3. Sort all fields by frequency.
%   4. Drop fields that older sweep versions created but never filled
%      (eff_worst_case, Volume_Trans).
%
% Output: `results` in the workspace. Save it to results/data/.

run_names = {'results40_150', 'results160_220', 'results230_250'};

runs = cellfun(@(name) evalin('base', name), run_names, 'UniformOutput', false);
fields = fieldnames(runs{1});

% 1. Concatenate along columns (one column per frequency point)
results = struct();
for i = 1:numel(fields)
    parts = cellfun(@(r) r.(fields{i}), runs, 'UniformOutput', false);
    results.(fields{i}) = [parts{:}];
end

% 2-3. Keep valid points, sorted by frequency
[~, order] = sort(results.freq);
order = order(results.freq(order) ~= 0);
n_total = numel(results.freq);
for i = 1:numel(fields)
    if size(results.(fields{i}), 2) == n_total
        results.(fields{i}) = results.(fields{i})(:, order);
    end
end

% 4. Remove unused legacy fields
legacy = intersect(fieldnames(results), {'eff_worst_case', 'Volume_Trans'});
results = rmfield(results, legacy);

clear runs fields parts order n_total legacy i
