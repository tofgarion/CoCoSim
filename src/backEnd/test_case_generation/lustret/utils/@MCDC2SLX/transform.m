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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%MCDC2SLX translate MC-DC conditions an EMF json file to Simulink blocks.
%Every node is translated to a subsystem. If OnlyMainNode is true than only
%the main node specified
%in main_node argument will be kept in the final simulink model.
function [status,...
        new_model_path, ...
        mcdc_trace] = transform(...
        json_path, ...
        mdl_trace, ...
        output_dir, ...
        new_model_name, ...
        main_node, ...
        organize_blocks)
    
    %% Init
    [coco_dir, cocospec_name, ~] = fileparts(json_path);
    if ~exist('mdl_trace', 'var') || isempty(mdl_trace)
        display_msg(...
            'Traceability from Simulink to Lustre is required',...
            MsgType.ERROR,...
            'mcdc2slx', '');
        return;
    end
    
    if ~exist('main_node', 'var') || isempty(main_node)
        onlyMainNode = false;
    else
        onlyMainNode = true;
    end
    if ~exist('organize_blocks', 'var') || isempty(organize_blocks)
        organize_blocks = true;
    end
    
    base_name = regexp(cocospec_name,'\.','split');
    if ~exist('new_model_name', 'var') || isempty(new_model_name)
        if onlyMainNode
            new_model_name = BUtils.adapt_block_name(strcat(base_name{1}, '_mcdc_', main_node));
        else
            new_model_name = BUtils.adapt_block_name(strcat(base_name{1}, '_mcdc_nodes'));
        end
    end
    
    %%
    try
        mdlTraceRoot = nasa_toLustre.utils.SLX2Lus_Trace.getxRoot(mdl_trace);
    catch
        display_msg(...
            ['file ' mdl_trace ' can not be read as xml file'],...
            MsgType.ERROR,...
            'mcdc2slx', '');
        return;
    end
    
    status = 0;
    display_msg('Runing MCDC2SLX on EMF file', MsgType.INFO, 'MCDC2SLX', '');
    
    if nargin < 2
        output_dir = coco_dir;
    end
    
    data = BUtils.read_json(json_path);
    
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    new_model_path = fullfile(output_dir,strcat(new_model_name,'.slx'));
    if exist(new_model_path,'file')
        if bdIsLoaded(new_model_name)
            close_system(new_model_name,0)
        end
        delete(new_model_path);
    end
    close_system(new_model_name,0);
    model_handle = new_system(new_model_name);
    
    xml_trace_file_name = fullfile(output_dir, ...
        strcat(cocospec_name, '.mcdc.trace.xml'));
    json_trace_file_name = fullfile(output_dir, ...
        strcat(cocospec_name, '.mcdc.trace.json'));
    mcdc_trace = nasa_toLustre.utils.SLX2Lus_Trace(new_model_path, ...
        xml_trace_file_name, json_trace_file_name);
    mcdc_trace.init();
    % save_system(model_handle,new_name);
    
    x = 200;
    y = -50;
    
    nodes = data.nodes;
    emf_fieldnames = fieldnames(nodes)';
    if onlyMainNode
        nodes_names = arrayfun(@(x)  nodes.(x{1}).original_name,...
            emf_fieldnames, 'UniformOutput', false);
        if ~ismember(main_node, nodes_names)
            msg = sprintf('Node "%s" not found in JSON "%s"', ...
                main_node, json_path);
            display_msg(msg, MsgType.ERROR, 'MCDC2SLX', '');
            status = 1;
            new_model_path = '';
            close_system(new_model_name,0);
            return
        end
        node_idx = ismember(nodes_names, main_node);
        node_name = emf_fieldnames{node_idx};
        node_block_path = fullfile(new_model_name, BUtils.adapt_block_name(main_node));
        block_pos = [(x+100) y (x+250) (y+50)];
        MCDC2SLX.mcdc_node_process(new_model_name, nodes, node_name, node_block_path, mdlTraceRoot, block_pos, mcdc_trace);
    else
        for node = emf_fieldnames
            try
                node_name = BUtils.adapt_block_name(node{1});
                display_msg(...
                    sprintf('Processing node "%s" ',node_name),...
                    MsgType.INFO, 'MCDC2SLX', '');
                y = y + 150;
                
                block_pos = [(x+100) y (x+250) (y+50)];
                node_block_path = fullfile(new_model_name,node_name);
                MCDC2SLX.mcdc_node_process(new_model_name, nodes, node{1}, node_block_path, mdlTraceRoot, block_pos,mcdc_trace);
                
            catch ME
                display_msg(['couldn''t translate node ' node{1} ' to Simulink'], MsgType.ERROR, 'MCDC2SLX', '');
                display_msg(ME.getReport(), MsgType.DEBUG, 'MCDC2SLX', '');
                %         continue;
                status = 1;
                return;
            end
        end
    end
    
    
    % Remove From Goto blocks and organize the blocks positions
    if organize_blocks
        goto_process( new_model_name );
        BlocksPosition_pp( new_model_name,2 );
    end
    % Write traceability informations
    mcdc_trace.write();
    configSet = getActiveConfigSet(model_handle);
    set_param(configSet, 'Solver', 'FixedStepDiscrete');
    save_system(model_handle,new_model_path,'OverwriteIfChangedOnDisk',true);
    
    % open_system(model_handle);
end

