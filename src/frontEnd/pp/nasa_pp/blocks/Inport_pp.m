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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [status, errors_msg] = Inport_pp( new_model_base )
status = 0;
errors_msg = {};

display_msg('Processing Inport blocks', MsgType.INFO, 'PP', '');

inport_list = find_system(new_model_base,'LookUnderMasks', 'all', 'BlockType','Inport');
model = regexp(new_model_base,'/','split');
model = model{1};
if ~isempty(inport_list)
        warning off;
        code_on=sprintf('%s([], [], [], ''compile'')', model);
        eval(code_on);
        dt_map = containers.Map();
        dim_map = containers.Map();
        for i=1:length(inport_list)
            port_dt = get_param(inport_list{i}, 'CompiledPortDataTypes');
            dt_map(inport_list{i}) = port_dt.Outport;
            port_dim = get_param(inport_list{i}, 'CompiledPortDimensions');
            dim_map(inport_list{i}) = port_dim.Outport(2:end);
        end
        code_off = sprintf('%s([], [], [], ''term'')', model);
        eval(code_off);
        %     warning on;
        for i=1:length(inport_list)
            try
                dt = dt_map(inport_list{i});
                if strcmp(dt, 'auto')
                    continue;
                end
                try
                    set_param(inport_list{i}, 'OutDataTypeStr', dt{1})
                catch
                    % case of bus signals is ignored.
                end
                dim = dim_map(inport_list{i});
                try
                    set_param(inport_list{i}, 'PortDimensions', mat2str(dim))
                catch me
                    display_msg(me.getReport(), MsgType.ERROR, 'Inport_pp', '');
                end
            catch
                status = 1;
                errors_msg{end + 1} = sprintf('Inport pre-process has failed for block %s', inport_list{i});
                continue;
            end
        end

end
end