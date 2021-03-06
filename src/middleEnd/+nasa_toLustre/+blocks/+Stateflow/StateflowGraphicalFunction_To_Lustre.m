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
classdef StateflowGraphicalFunction_To_Lustre
    %StateflowGraphicalFunction_To_Lustre
    
    
    properties
    end
    
    methods(Static)
        
        function  [main_node, external_nodes, external_libraries ] = ...
                write_code(sfunc, chart_data)
            
            global SF_MF_FUNCTIONS_MAP SF_JUNCTIONS_PATH_MAP SF_STATES_NODESAST_MAP;
            if isempty(SF_JUNCTIONS_PATH_MAP)
                SF_JUNCTIONS_PATH_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            if isempty(SF_MF_FUNCTIONS_MAP)
                SF_MF_FUNCTIONS_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            if isempty(SF_STATES_NODESAST_MAP)
                SF_STATES_NODESAST_MAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            external_nodes = {};
            external_libraries = {};
            % add junctions
            junctions = sfunc.Junctions;
            for i=1:numel(junctions)
                SF_JUNCTIONS_PATH_MAP(junctions{i}.Path) = junctions{i};
            end
            data_map = chart_data;
            func_inputs = {};
            func_outputs = {};
            for i=1:numel(sfunc.Data)
                x = sfunc.Data{i};
                data_map(sfunc.Data{i}.Name) = x;
                if strcmp(x.Scope, 'Input')
                    func_inputs{end+1} = nasa_toLustre.lustreAst.LustreVar(x.Name, x.LusDatatype);
                elseif strcmp(x.Scope, 'Output')
                    func_outputs{end+1} = nasa_toLustre.lustreAst.LustreVar(x.Name, x.LusDatatype);
                end
            end
            % Go over Junctions Outertransitions: condition/Transition Actions
            for i=1:numel(junctions)
                try
                    [external_nodes_i, external_libraries_i ] = ...
                        nasa_toLustre.blocks.Stateflow.StateflowJunction_To_Lustre.write_code(junctions{i}, data_map);
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
            
            % create main node
            parentPath = sfunc.Path;
            T = sfunc.Composition.DefaultTransitions;
            isDefaultTrans = true;
            % Default transitions actions
            [transition_nodes_j, external_libraries_j ] = ...
                nasa_toLustre.blocks.Stateflow.StateflowTransition_To_Lustre.get_Actions(T{1}, data_map, sfunc, ...
                isDefaultTrans);
            external_nodes = [external_nodes, transition_nodes_j];
            external_libraries = [external_libraries, external_libraries_j];
            
            
            node_name = nasa_toLustre.blocks.Stateflow.utils.SF2LusUtils.getUniqueName(sfunc);
            comment = nasa_toLustre.lustreAst.LustreComment(...
                sprintf('Stateflow Graphical Function %s', sfunc.Origin_path), true);
            [main_node, external_libraries_i] = ...
                nasa_toLustre.blocks.Stateflow.StateflowTransition_To_Lustre.getTransitionsNode(T, data_map, ...
                parentPath, ...
                isDefaultTrans, ...
                node_name, comment);
            external_libraries = [external_libraries, external_libraries_i];
            if isempty(main_node)
                return;
            end
            %Stateflow function may use chart Data as global data and modify it.
            computed_inputs = main_node.getInputs();
            computed_outputs = main_node.getOutputs();
            if ~isempty(func_outputs)
                main_node.setOutputs(func_outputs);
                if numel(func_outputs) ~= numel(computed_outputs)
                    display_msg(...
                        sprintf(['Stateflow Function %s has %d outputs.'...
                        ' But %d variable has been changed in Condition Actions inside the Function.'], ...
                        sfunc.Origin_path, numel(func_outputs), numel(computed_outputs)), ...
                        MsgType.ERROR, 'StateflowGraphicalFunction_To_Lustre', '');
                end
            elseif isempty(computed_outputs)
                % no body has been generated
                return;
            end
            if ~isempty(func_inputs)
                main_node.setInputs(func_inputs);
                if numel(func_inputs) < numel(computed_inputs)
                    bodyEqs = main_node.getBodyEqs();
                    for i=1:numel(computed_inputs)
                        if nasa_toLustre.lustreAst.VarIdExpr.ismemberVar(computed_inputs{i}, func_inputs)
                            continue;
                        end
                        if nasa_toLustre.lustreAst.VarIdExpr.ismemberVar(computed_inputs{i}, func_outputs)
                            % substitute first occurance of the variable by zero
                            var = nasa_toLustre.lustreAst.VarIdExpr(computed_inputs{i}.getId());
                            var_dt = computed_inputs{i}.getDT();
                            for j=1:numel(bodyEqs)
                                if isa(bodyEqs{j}, 'nasa_toLustre.lustreAst.LustreEq')
                                    lhs = bodyEqs{j}.getLhs();
                                    rhs = bodyEqs{j}.getRhs();
                                    nb_occ = rhs.nbOccuranceVar(var);
                                    if nb_occ > 0
                                        newVar =nasa_toLustre.utils.SLX2LusUtils.num2LusExp(0, var_dt);
                                        new_rhs = rhs.substituteVars( var, newVar);
                                        bodyEqs{j} = nasa_toLustre.lustreAst.LustreEq(lhs, new_rhs);
                                        break;
                                    end
                                end
                            end
                        end
                    end
                    main_node.setBodyEqs(bodyEqs);
                end
            end
            
            
            SF_STATES_NODESAST_MAP(node_name) = main_node;
            SF_MF_FUNCTIONS_MAP(sfunc.Name) = main_node;
            
            
        end
        function options = getUnsupportedOptions(~, varargin)
            options = {};
            
        end
        %%
        function is_Abstracted = isAbstracted(varargin)
            is_Abstracted = false;
        end
        
    end
    
end

