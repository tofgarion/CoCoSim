%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Author: Hamza Bourbouh <hamza.bourbouh@nasa.gov>
% Notices:
%
% Copyright @ 2020 United States Government as represented by the 
% Administrator of the National Aeronautics and Space Administration.  All 
% Rights Reserved.
%
% Disclaimers
%
% No Warranty: THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY 
% WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING,
% BUT NOT LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM 
% TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS 
% FOR A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT
% THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT 
% DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS 
% AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY 
% GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING 
% DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING 
% FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS 
% ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF PRESENT 
% IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS."
%
% Waiver and Indemnity:  RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS 
% AGAINST THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS, 
% AS WELL AS ANY PRIOR RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT 
% SOFTWARE RESULTS IN ANY LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR 
% LOSSES ARISING FROM SUCH USE, INCLUDING ANY DAMAGES FROM PRODUCTS BASED 
% ON, OR RESULTING FROM, RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT 
% SHALL INDEMNIFY AND HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS 
% CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE 
% EXTENT PERMITTED BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER 
% SHALL BE THE IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.
% 
% Notice: The accuracy and quality of the results of running CoCoSim 
% directly corresponds to the quality and accuracy of the model and the 
% requirements given as inputs to CoCoSim. If the models and requirements 
% are incorrectly captured or incorrectly input into CoCoSim, the results 
% cannot be relied upon to generate or error check software being developed. 
% Simply stated, the results of CoCoSim are only as good as
% the inputs given to CoCoSim.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

%% This function is used to compare two simulink models simulations or Simulink again lustre.
% It's used by both validating Simulink original VS pp model and validating
% PP model Vs Lustre file
function [valid, cex_msg, diff_name, diff_value, sim_failed] = ...
        compare_slx_out_with_lusORslx_out(...
        input_dataSet, ...
        yout1,...
        yout2, ...
        lus_outs, ...
        eps, ...
        time)
    diff_name = '';
    diff_value = 0;
    numberOfOutputs = length(yout1.getElementNames);
    numberOfInports = length(input_dataSet.getElementNames);
    valid = false;
    cex_msg = {};
    index_out = 0;
    sim_failed = false;
    isComparingAgainstLustre = ~isempty(lus_outs);
    out_width = zeros(numberOfOutputs,1);
    for k=1:numberOfOutputs
        out_width(k) = LustrecUtils.getSignalWidth(yout1{k}.Values);
    end
    first_comparaison = true;
    for i=1:numel(time)
        cex_msg{end+1} = sprintf('*****time : %f**********\n',time(i));
        cex_msg{end+1} = sprintf('*****inputs: \n');
        for j=1:numberOfInports
            in = LustrecUtils.getSignalValuesInlinedUsingTime(input_dataSet{j}.Values, time(i));
            in_width = numel(in);
            name = input_dataSet{j}.Name;
            for jk=1:in_width
                cex_msg{end+1} = sprintf('input %s_%d: %f\n',name,jk,in(jk));
            end
        end
        cex_msg{end+1} = sprintf('*****outputs: \n');
        found_output = false;
        for k=1:numberOfOutputs
            yout1_values = LustrecUtils.getSignalValuesInlinedUsingTime(yout1{k}.Values, time(i));
            if ~isComparingAgainstLustre
                yout2_values = LustrecUtils.getSignalValuesInlinedUsingTime(yout2{k}.Values, time(i));
            end
            if isempty(yout1_values) || (~isComparingAgainstLustre && isempty(yout2_values))
                % signal is not defined in the current timestep
                index_out = index_out + out_width(k);
                continue;
            end
            if ~isComparingAgainstLustre && numel(yout1_values) ~= numel(yout2_values)
                % Signature is not the same
                valid = false;
                sim_failed = true;
                return;
            end
            found_output = true;
            for j=1:out_width(k)
                y1_value = double(yout1_values(j));
                fst_output_name = sprintf('%s(%d)',...
                        BUtils.naming_alone(yout1{k}.BlockPath.getBlock(1)), ...
                        j);
                if ~isComparingAgainstLustre
                    y2_value = double(yout2_values(j));
                    second_output_name = sprintf('%s(%d)',...
                        BUtils.naming_alone(yout2{k}.BlockPath.getBlock(1)), ...
                        j);
                else
                    index_out = index_out + 1;
                    output_value = ...
                        regexp(lus_outs{index_out},...
                        '\s*:\s*',...
                        'split');
                    if isempty(output_value)
                        warn = sprintf('strange behavour of output %s',...
                            lus_outs{numberOfOutputs*(i-1)+k});
                        cex_msg{end+1} = warn;
                        display_msg(warn,...
                            MsgType.WARNING,...
                            'compare_Simu_outputs_with_Lus_outputs',...
                            '');
                        valid = false;
                        break;
                    end
                    second_output_name = output_value{1};
                    output_val_str = output_value{2};
                    output_val_str = strrep(output_val_str, ' ', '');
                    y2_value = str2double(output_val_str(2:end-1));
                end
                    
                cex_msg{end+1} = sprintf('Simulink output %s: %10.16f\n',...
                    fst_output_name, y1_value);
                if isComparingAgainstLustre
                    cex_msg{end+1} = sprintf('Lustre output %s: %10.16f\n',...
                        second_output_name,y2_value);
                else
                    cex_msg{end+1} = sprintf('Simulink PP output %s: %10.16f\n',...
                        second_output_name,y2_value);
                end
                
                if isinf(y1_value) || isnan(y1_value)...
                        || isinf(y2_value) || isnan(y2_value)
                    diff=0;
                elseif abs(y1_value) > 10^10 && abs(y1_value-y2_value) > eps
                    diff = abs(y1_value-y2_value)/y1_value;
                else
                    diff = abs(y1_value-y2_value);
                end
                
                if first_comparaison
                    valid = diff <  eps;
                    first_comparaison = false;
                else
                    valid = valid && (diff <  eps);
                end
                if  isempty(diff_name) && (diff >= eps)
                    diff_name =  ...
                        BUtils.naming_alone(yout1{k}.BlockPath.getBlock(1));
                    diff_name =  strcat(diff_name, '(',num2str(j), ')');
                    diff_value = diff;
                    % don't break now untile this timestep finish displatyin all outputs
                    %break
                end
            end
        end
        if ~found_output
            cex_msg{end+1} = sprintf('No Output saved for this time step.\n');
        end
        if  found_output && ~valid
            break;
        end
    end
end

