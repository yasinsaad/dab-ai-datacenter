% Assuming your three structs are named results1, results2, and results3
% and they all have the exact same fields (freq, S11, power, etc.)

results = struct();
fields = fieldnames(results40_150);

% 1. Concatenate all data into a single struct
for i = 1:length(fields)
    fieldName = fields{i};
    
    % The (:) ensures they are column vectors before stacking, 
    % which prevents dimension mismatch errors.
    results.(fieldName) = [results40_150.(fieldName),results160_220.(fieldName), results230_250.(fieldName)]
end

%% 2. Sort the frequency array AND extract the sorting index (sortIdx)
%mergedresults.freq = mergedresults.freq(mergedresults.freq~= 0);
%[mergedresults.freq, sortIdx] = sort(mergedresults.freq);
results = rmfield(results,'eff_worst_case' )
results = rmfield(results,'Volume_Trans' )
fields = fieldnames(results);
non0 = (results.freq ~=0)
% 3. Apply the sorting index to all other fields to maintain the correct sequence
for i = 1:length(fields)
    fieldName = fields{i}
    
    % Skip 'freq' because we already sorted it in the previous step
    if strcmp(fieldName, 'Volume_T')
        continue
    elseif ~strcmp(fieldName, 'breakdown') 
        % Reorder the array using the index mapped from the frequency sort
        results.(fieldName) = results.(fieldName)(non0);
    else 
        mask = 1:31;
        mask = mask(~non0);
        
        for k= flip(mask)
            
            results.breakdown(:,k) = []
        end
        
    end
end