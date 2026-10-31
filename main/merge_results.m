%% MERGE_RESULTS  Join sweep results from several runs into one `results` struct.
%
% Use when one frequency range was swept in several runs.
%
% Workspace inputs (not in the repo; load your partial runs first):
%   results40_150, results160_220, results230_250
%       `results` structs from main/DAB_freq_sweep.m with the same fields.
%
% Steps:
%   1. Concatenate every field in run order.
%   2. Drop the unused fields eff_worst_case and Volume_Trans.
%   3. Remove points with freq == 0 (failed or skipped simulations).
%
% Output: `results` in the workspace. Save it to results/data/.
%
% Limitation: the breakdown cleanup assumes 31 merged points in total
% (`mask = 1:31`). Change it if the runs cover a different number of
% frequencies.


results = struct();
fields = fieldnames(results40_150);

% 1. Concatenate all data into a single struct
for i = 1:length(fields)
    fieldName = fields{i};
    
    % Fields are row vectors (breakdown is 7xN), so concatenate along columns.
    results.(fieldName) = [results40_150.(fieldName),results160_220.(fieldName), results230_250.(fieldName)]
end

%% 2. Remove unused fields and failed points
% (Sorting by frequency is disabled; runs are concatenated in order.)
%mergedresults.freq = mergedresults.freq(mergedresults.freq~= 0);
%[mergedresults.freq, sortIdx] = sort(mergedresults.freq);
results = rmfield(results,'eff_worst_case' )
results = rmfield(results,'Volume_Trans' )
fields = fieldnames(results);
non0 = (results.freq ~=0)
% 3. Keep only points with freq ~= 0 in every field
for i = 1:length(fields)
    fieldName = fields{i}
    
    % Volume_T is skipped (left unfiltered); breakdown is 7xN, so its
    % zero-frequency columns are deleted one by one from the end.
    if strcmp(fieldName, 'Volume_T')
        continue
    elseif ~strcmp(fieldName, 'breakdown') 
        results.(fieldName) = results.(fieldName)(non0);
    else 
        mask = 1:31;
        mask = mask(~non0);
        
        for k= flip(mask)
            
            results.breakdown(:,k) = []
        end
        
    end
end