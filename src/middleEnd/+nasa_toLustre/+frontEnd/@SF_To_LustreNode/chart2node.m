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
function [main_node, external_nodes, external_libraries ] = ...
        chart2node(parent,  chart,  main_sampleTime, lus_backend, xml_trace)
    %the main function

    
    %
    %
    % global varibale mapping between states and their nodes AST.
    global SF_STATES_NODESAST_MAP SF_STATES_PATH_MAP ...
        SF_JUNCTIONS_PATH_MAP SF_STATES_ENUMS_MAP ...
        SF_MF_FUNCTIONS_MAP TOLUSTRE_ENUMS_MAP;
    %It's initialized for each call of this function
    SF_STATES_NODESAST_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    SF_STATES_PATH_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    SF_JUNCTIONS_PATH_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    SF_STATES_ENUMS_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    SF_MF_FUNCTIONS_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    SF_DATA_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % initialize outputs
    main_node = {};
    external_nodes = {};
    external_libraries = {};
    
    % get content
    content = chart.StateflowContent;
    events = nasa_toLustre.blocks.Stateflow.utils.SF2LusUtils.eventsToData(content.Events);
    dataAndEvents = [events; content.Data];
    for i=1:numel(dataAndEvents)
        SF_DATA_MAP(dataAndEvents{i}.Name) = dataAndEvents{i};
    end
    SF_DATA_MAP = nasa_toLustre.blocks.Stateflow.utils.SF2LusUtils.addArrayData(SF_DATA_MAP, dataAndEvents);
    states = nasa_toLustre.blocks.Stateflow.utils.SF2LusUtils.orderObjects(content.States);
    for i=1:numel(states)
        SF_STATES_PATH_MAP(states{i}.Path) = states{i};
    end
    junctions = content.Junctions;
    for i=1:numel(junctions)
        SF_JUNCTIONS_PATH_MAP(junctions{i}.Path) = junctions{i};
    end
    % Go Over Stateflow Functions
    if isfield(content, 'GraphicalFunctions')
        SFFunctions = content.GraphicalFunctions;
        for i=1:numel(SFFunctions)
            sfunc = SFFunctions{i};
            try
                [node_i, external_nodes_i, external_libraries_i ] = ...
                    nasa_toLustre.blocks.Stateflow.StateflowGraphicalFunction_To_Lustre.write_code(...
                    sfunc, SF_DATA_MAP);
                if iscell(node_i)
                    external_nodes = [external_nodes, node_i];
                else
                    external_nodes{end+1} = node_i;
                end
                external_nodes = [external_nodes, external_nodes_i];
                external_libraries = [external_libraries, external_libraries_i];
            catch me
                if strcmp(me.identifier, 'COCOSIM:STATEFLOW')
                    display_msg(me.message, MsgType.ERROR, 'SF_To_LustreNode', '');
                else
                    display_msg(me.getReport(), MsgType.DEBUG, 'SF_To_LustreNode', '');
                end
                display_msg(sprintf('Translation of Stateflow Function %s failed', ...
                    sfunc.Origin_path),...
                    MsgType.ERROR, 'SF_To_LustreNode', '');
            end
            
        end
    end
    
    % Go over Truthtables
    if isfield(content, 'TruthTables')
        truthTables = content.TruthTables;
        for i=1:numel(truthTables)
            table = truthTables{i};
            try
                [node_i, external_nodes_i, external_libraries_i ] = ...
                    nasa_toLustre.blocks.Stateflow.StateflowTruthTable_To_Lustre.write_code(...
                    table, SF_DATA_MAP, content);
                if iscell(node_i)
                    external_nodes = [external_nodes, node_i];
                else
                    external_nodes{end+1} = node_i;
                end
                external_nodes = [external_nodes, external_nodes_i];
                external_libraries = [external_libraries, external_libraries_i];
            catch me
                
                if strcmp(me.identifier, 'COCOSIM:STATEFLOW')
                    display_msg(me.message, MsgType.ERROR,...
                        'SF_To_LustreNode', '');
                else
                    display_msg(me.getReport(), MsgType.DEBUG, ...
                        'SF_To_LustreNode', '');
                end
                display_msg(sprintf('Translation of TruthTable %s failed', ...
                    table.Path),...
                    MsgType.ERROR, 'SF_To_LustreNode', '');
            end
        end
    end
    % Go over Junctions Outertransitions: condition/Transition Actions
    for i=1:numel(junctions)
        try
            [external_nodes_i, external_libraries_i ] = ...
                nasa_toLustre.blocks.Stateflow.StateflowJunction_To_Lustre.write_code(junctions{i}, SF_DATA_MAP);
            external_nodes = [external_nodes, external_nodes_i];
            external_libraries = [external_libraries, external_libraries_i];
        catch me
            if strcmp(me.identifier, 'COCOSIM:STATEFLOW')
                display_msg(me.message, MsgType.ERROR, 'SF_To_LustreNode', '');
            else
                display_msg(me.getReport(), MsgType.DEBUG, 'SF_To_LustreNode', '');
            end
            display_msg(sprintf('Translation of Junction %s failed', ...
                junctions{i}.Origin_path),...
                MsgType.ERROR, 'SF_To_LustreNode', '');
        end
    end
    
    % Go over states: for state actions
    for i=1:numel(states)
        try
            [external_nodes_i, external_libraries_i ] = ...
                nasa_toLustre.blocks.Stateflow.StateflowState_To_Lustre.write_ActionsNodes(...
                states{i}, SF_DATA_MAP);
            external_nodes = [external_nodes, external_nodes_i];
            external_libraries = [external_libraries, ...
                external_libraries_i];
        catch me
            
            if strcmp(me.identifier, 'COCOSIM:STATEFLOW')
                display_msg(me.message, MsgType.ERROR,...
                    'SF_To_LustreNode', '');
            else
                display_msg(me.getReport(), MsgType.DEBUG, ...
                    'SF_To_LustreNode', '');
            end
            display_msg(sprintf('Translation of state %s failed', ...
                states{i}.Origin_path),...
                MsgType.ERROR, 'SF_To_LustreNode', '');
        end
    end
    % Go over states: for state Transitions
    % the previous loop should be performed before this one so all
    % state actions signature are stored.
    for i=1:numel(states)
        try
            [external_nodes_i, external_libraries_i ] = ...
                nasa_toLustre.blocks.Stateflow.StateflowState_To_Lustre.write_TransitionsNodes(...
                states{i}, SF_DATA_MAP);
            external_nodes = [external_nodes, external_nodes_i];
            external_libraries = [external_libraries, ...
                external_libraries_i];
        catch me
            
            if strcmp(me.identifier, 'COCOSIM:STATEFLOW')
                display_msg(me.message, MsgType.ERROR, ...
                    'SF_To_LustreNode', '');
            else
                display_msg(me.getReport(), MsgType.DEBUG, ...
                    'SF_To_LustreNode', '');
            end
            display_msg(sprintf('Translation of state %s failed', ...
                states{i}.Origin_path),...
                MsgType.ERROR, 'SF_To_LustreNode', '');
        end
    end
    
    % Go over states for state Nodes
    for i=1:numel(states)
        try
            node = nasa_toLustre.blocks.Stateflow.StateflowState_To_Lustre.write_StateNode(...
                states{i});
            if ~isempty(node)
                external_nodes{end+1} = node;
            end
        catch me
            
            if strcmp(me.identifier, 'COCOSIM:STATEFLOW')
                display_msg(me.message, MsgType.ERROR, ...
                    'SF_To_LustreNode', '');
            else
                display_msg(me.getReport(), MsgType.DEBUG, ...
                    'SF_To_LustreNode', '');
            end
            display_msg(sprintf('Translation of state %s failed', ...
                states{i}.Origin_path),...
                MsgType.ERROR, 'SF_To_LustreNode', '');
        end
    end
    
    %Chart node
    [main_node, external_nodes_i] =...
        nasa_toLustre.blocks.Stateflow.StateflowState_To_Lustre.write_ChartNode(parent, chart, states{end}, dataAndEvents, events);
    external_nodes = [external_nodes, ...
        external_nodes_i];
    
    %change from imperative code to Lustre
    %main_node = main_node.pseudoCode2Lustre(SF_DATA_MAP);% already handled
    for i=1:numel(external_nodes)
        external_nodes{i} = external_nodes{i}.pseudoCode2Lustre(SF_DATA_MAP);
    end
    
    % add Stateflow Enumerations to ToLustre set of enumerations.
    keys = SF_STATES_ENUMS_MAP.keys();
    for i=1:numel(keys)
        TOLUSTRE_ENUMS_MAP(keys{i}) = ...
            cellfun(@(x) nasa_toLustre.lustreAst.EnumValueExpr(x), SF_STATES_ENUMS_MAP(keys{i}), ...
            'UniformOutput', false);
    end
end

