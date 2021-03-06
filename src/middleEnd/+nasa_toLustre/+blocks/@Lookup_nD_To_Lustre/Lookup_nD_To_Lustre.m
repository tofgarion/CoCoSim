%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Author: Trinh, Khanh V <khanh.v.trinh@nasa.gov>
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
classdef Lookup_nD_To_Lustre < nasa_toLustre.frontEnd.Block_To_Lustre ...
        & nasa_toLustre.blocks.BaseLookup
    % Lookup_nD_To_Lustre
    % This class will do linear interpolation for up to 7 dimensions.  For
    % some options like flat and nearest, values at the breakpoints are
    % returned.  For the "linear" option, the interpolation
    % technique used here is based on using shape functions (using finite
    % element terminology).  A reference describing this technique is
    % "Multi-Linear Interpolation" by Rick Wagner (Beach Cities Robotics,
    % First team 294).
    % http://bmia.bmt.tue.nl/people/BRomeny/Courses/8C080/Interpolation.pdf.
    % We are looking for y = f(u1,u2,...u7) where u1, u2 are coordinate
    % values of dimension 1 and dimension 2 respectively for the point of interest.
    % We can obtain y from the interpolation equation
    % y(u1,u2,u3,...) = u1*N1(u1,u2,...) + u2*N2(u1,u2,...) + ...
    % u3*N3(u1,u2,...) + ... + u7*N7(u1,u2,...)
    % N1,N2 are shape functions for the 2 bounding nodes of dimension 1.
    % N3, N4 are shape functions for the 2 bounding nodes of dimension 2.The shape functions
    % are defined by coordinates of the polytope with nodes (breakpoints in
    % simulink dialog) surrounding the point of interest.
    % The interpolation codes are done on the Lustre side.  In this
    % implementation, we do the main interpolation in Lustre external
    % nodes.  The main node just call the external node passing in the coordinates
    % of the point to be interpolated.  Table data is stored in the
    % external node.  The major steps for writing the external node are:
    %         1. define the breakpoints and table values defined by users (function
    %         addBreakpointCode and addBreakpointCode).
    %         2. finding the bounding polytop which is required to define
    %         the shape functions.  For each dimension, there will be 2
    %         breakpoints that surround the coordinate of the interpolation
    %         point in that dimension.  For 2 dimensions, if the table is a
    %         mesh, then the polytop is a quadrilateral containing the
    %         interpolation point.  Defining the bounding nodes is done in
    %         the function addBoundNodeCode.
    %         3. defining dimJump.  table breakpoints and values are inline in Lustre, the
    %         interpolation formulation uses index for each dimension.  We
    %         need to get the inline data from the dimension subscript.
    %         Function addDimJumpCode calculate the index jump in the inline when we
    %         change dimension subscript.  For example dimJump(2) = 3 means
    %         to increase subscript dimension 2 by 1, we have to jump 3
    %         spaces in the inline storage (addDimJumpCode).  See comments
    %         at the top of Assignment_To_Lustre.m for code example of
    %         getting inline index from subscripts of a multidimensional
    %         array.
    %         4. defining and calculating shape function values for the
    %         interpolation point (addShapeFunctionCode).
    %         5. carrying out the interpolation depending on algorithm
    %         option.  For the flat option, the value at the lower bounding
    %         breakpoint is used. For the nearest option, the closest
    %         bounding node for each dimension is used.  We are not
    %         calculating the distance from the interpolated point to each
    %         of the bounding node on the polytop containing the
    %         interpolated point. For the "clipped" extrapolation option, the nearest
    %         breakpoint in each dimension is used. Cubic spline is not
    %         supported
    %
    %         contract
    %         if u (interpolation point) lies inside the polytop, then y >=
    %         smallest table value and y <= largest table value.
    %         if interpolation method = 'Flat',  then y >=
    %         smallest table value and y <= largest table value.
    %         if interpolation method = 'Nearest',  then y >=
    %         smallest table value and y <= largest table value.
    %         if extrapolation method = 'Clip',  then y >=
    %         smallest table value and y <= largest table value.

%    
    properties
    end
    
    methods
        
        function  write_code(obj, parent, blk, xml_trace, ...
                lus_backend, coco_backend, main_sampleTime, varargin)
            global  CoCoSimPreferences;
            % codes are shared between Lookup_nD_To_Lustre and LookupTableDynamic
            blkParams = ...
                nasa_toLustre.blocks.Lookup_nD_To_Lustre.getInitBlkParams(...
                blk,lus_backend);
            
            blkParams = obj.readBlkParams(parent,blk,blkParams);
            
            % get block outputs
            [outputs, outputs_dt] = ...
                nasa_toLustre.utils.SLX2LusUtils.getBlockOutputsNames(...
                parent, blk, [], xml_trace, main_sampleTime);
            obj.addVariable(outputs_dt);
            
            % get block inputs and cast them to real
            widths = blk.CompiledPortWidths.Inport;
            numInputs = numel(widths);
            max_width = max(widths);
            RndMeth = blkParams.RndMeth;
            SaturateOnIntegerOverflow = blkParams.SaturateOnIntegerOverflow;
            inputs = cell(1, numInputs);
            for i=1:numInputs
                inputs{i} =nasa_toLustre.utils.SLX2LusUtils.getBlockInputsNames(parent, blk, i);
                slx_inport_dt = blk.CompiledPortDataTypes.Inport{i};
                Lusinport_dt =nasa_toLustre.utils.SLX2LusUtils.get_lustre_dt(slx_inport_dt);
                if numel(inputs{i}) < max_width
                    inputs{i} = arrayfun(@(x) {inputs{i}{1}}, (1:max_width));
                end
                %converts the input data type(s) to real if not real
                if ~strcmp(Lusinport_dt, 'real')
                    [external_lib, conv_format] = ...
                        nasa_toLustre.utils.SLX2LusUtils.dataType_conversion(slx_inport_dt, 'real', RndMeth, SaturateOnIntegerOverflow);
                    if ~isempty(conv_format)
                        obj.addExternal_libraries(external_lib);
                        inputs{i} = cellfun(@(x) ...
                            nasa_toLustre.utils.SLX2LusUtils.setArgInConvFormat(conv_format,x),...
                            inputs{i}, 'un', 0);
                    end
                end
            end
            
            % For n-D Lookup Table, if UseOneInputPortForAllInputData is
            % selected, Combine all input data to one input port
            inputs = ...
                nasa_toLustre.blocks.Lookup_nD_To_Lustre.useOneInputPortForAllInputData(...
                blk,inputs,blkParams.NumberOfTableDimensions);
            
            obj.addExternal_libraries({'LustMathLib_abs_real'});
            wrapperNode = obj.create_lookup_nodes(blk,lus_backend,blkParams,outputs,inputs);
            mainCode = obj.getMainCode(blk,outputs,inputs,...
                wrapperNode,blkParams);
            obj.addCode(mainCode);
            
            %% Design Error Detection Backend code:
            if CoCoBackendType.isDED(coco_backend)
                if ismember(CoCoBackendType.DED_OUTMINMAX, ...
                        CoCoSimPreferences.dedChecks)
                    outputDataType = blk.CompiledPortDataTypes.Outport{1};
                    lusOutDT =nasa_toLustre.utils.SLX2LusUtils.get_lustre_dt(outputDataType);
                    DEDUtils.OutMinMaxCheckCode(obj, parent, blk, outputs, lusOutDT, xml_trace);
                end
            end
        end
        %%
        function options = getUnsupportedOptions(obj, parent, blk, varargin)
            L = nasa_toLustre.ToLustreImport.L;
            import(L{:})
            [NumberOfTableDimensions, ~, ~] = ...
                Constant_To_Lustre.getValueFromParameter(parent, ...
                blk, blk.NumberOfTableDimensions);
            LusOutport_dt =nasa_toLustre.utils.SLX2LusUtils.get_lustre_dt(blk.CompiledPortDataTypes.Outport{1});
            if NumberOfTableDimensions > 7
                obj.addUnsupported_options(sprintf(...
                    'More than 7 dimensions is not supported in block %s',...
                    HtmlItem.addOpenCmd(blk.Origin_path)));
            end
            if strcmp(blk.InterpMethod, 'Cubic spline')
                obj.addUnsupported_options(sprintf(...
                    'Cubic spline interpolation is not support in block %s',...
                    HtmlItem.addOpenCmd(blk.Origin_path)));
            end
            
            
            if strcmp(blk.InterpMethod,'Linear') ...
                    && ~(...
                    strcmp(blk.IntermediateResultsDataTypeStr,'Inherit: Inherit via internal rule')...
                    || (strcmp(blk.IntermediateResultsDataTypeStr,'Inherit: Same as output') && strcmp(LusOutport_dt, 'real') ) ...
                    ||strcmp(blk.IntermediateResultsDataTypeStr,'single') ...
                    ||strcmp(blk.IntermediateResultsDataTypeStr,'double'))
                obj.addUnsupported_options(sprintf(...
                    'IntermediateResultsDataTypeStr in block "%s" should be double or single',...
                    HtmlItem.addOpenCmd(blk.Origin_path)));
            end
            
            options = obj.unsupported_options;
        end
        %%
        function is_Abstracted = isAbstracted(varargin)
            is_Abstracted = false;
        end
        
        blkParams = readBlkParams(obj,parent,blk,blkParams)
        
        wrapperNode = create_lookup_nodes(obj,blk,lus_backend,blkParams,outputs,inputs)
        
        extNode =  get_wrapper_node(obj,blk,blkParams,inputs,...
            preLookUpExtNode,interpolationExtNode)
        
        [mainCode, main_vars] = getMainCode(obj, blk,outputs,inputs,...
            lookupWrapperExtNode,blkParams)
        
    end
    
    methods(Static)
        
        inputs = useOneInputPortForAllInputData(blk,lookupTableType,...
            inputs,NumberOfTableDimensions)
        
        %         [inputs,zero,one, external_lib] = ...
        %             getBlockInputsNames_convInType2AccType(parent, blk,...
        %             lookupTableType)
        
        extNode = get_pre_lookup_node(lus_backend,blkParams,inputs)
        
        extNode = get_interp_using_pre_node(obj, blkParams, inputs)
        
        extNode = get_read_table_node(blkParams, inputs)
        
        [body, vars,Ast_dimJump] = addDimJumpCode(...
            NumberOfTableDimensions,blk_name,indexDataType,blkParams)
        
        [body,vars,Breakpoints] = addBreakpointCode(blkParams,node_header)
        
        [body, vars,coords_node,index_node] = addBoundNodeCode(...
            blkParams,Breakpoints,node_header,lus_backend)
        
        [body, vars, boundingi] = ...
            addBoundNodeInlineIndexCode(index_node,Ast_dimJump,blkParams)
        
        [body,vars,table_elem] = addTableCode(blkParams,node_header)
        
        [body, vars] = addDirectLookupNodeCode(...
            blkParams,index_node,coords_node, coords_input ,...
            Ast_dimJump)
        
        shapeNodeSign = getShapeBoundingNodeSign(dims)
        
        [body, vars] = addInlineIndexFromArrayIndicesCode(blkParams,...
            Breakpoints,node_header,lus_backend, lusOutDT)
        
        [body, vars, N_shape_node] = addNodeWeightsCode(node_inputs,...
            coords_node,blkParams,lus_backend)
        
        [body, vars,u_node] = addUnodeCode(numBoundNodes,...
            boundingi,blkParams, readTableNodeName, readTableInputs)
        
        contractBody = getContractBody(blkParams,inputs,outputs)
        
        ep = calculate_eps(BP, j)
        
        y_interp = interp2points_2D(x1, y1, x2, y2, x_interp)
        
        function blkParams = getInitBlkParams(blk,lus_backend)
            blkParams = struct;
            blkParams.BreakpointsForDimension = {};
            blkParams.directLookup = 0;
            blkParams.yIsBounded = 0;
            blkParams.blk_name = ...
                nasa_toLustre.utils.SLX2LusUtils.node_name_format(blk);
            blkParams.RndMeth = 'Round';
            blkParams.SaturateOnIntegerOverflow = 'off';
            blkParams.lus_backend = lus_backend;
            % inititalize tableIsInputPort and bpIsInputPort to false
            blkParams.tableIsInputPort =  false;
            blkParams.bpIsInputPort =  false;
        end
        
        function blkParams = addCommonData2BlkParams(blkParams)
            % calculate dimJump
            [~, ~,Ast_dimJump] = ...
                nasa_toLustre.blocks.Lookup_nD_To_Lustre.addDimJumpCode(blkParams);
            blkParams.Ast_dimJump = Ast_dimJump;
            % direct method variable names
            blkParams.direct_sol_inline_index_VarIdExpr = ...
                nasa_toLustre.lustreAst.VarIdExpr(...
                'direct_solution_inline_index');
            blkParams.sol_subs_for_dim = ...
                cell(1,blkParams.NumberOfTableDimensions);
            for i=1:blkParams.NumberOfTableDimensions
                % solution node subscript for each dimension
                blkParams.sol_subs_for_dim{i} = ...
                    nasa_toLustre.lustreAst.VarIdExpr(...
                    sprintf('solution_subscript_for_dim_%d',i));
            end
            
        end

        
        function [output_conv_format, external_lib]  = ...
                get_output_conv_format(blk,blkParams)
            slx_outputDataType = blk.CompiledPortDataTypes.Outport{1};
            lus_out_type =...
                nasa_toLustre.utils.SLX2LusUtils.get_lustre_dt(slx_outputDataType);
            
            if ~strcmp(lus_out_type,'real')
                RndMeth = blkParams.RndMeth;
                SaturateOnIntegerOverflow = blkParams.SaturateOnIntegerOverflow;
                [external_lib, output_conv_format] =...
                    nasa_toLustre.utils.SLX2LusUtils.dataType_conversion('real', ...
                    slx_outputDataType, RndMeth, SaturateOnIntegerOverflow);
            else
                output_conv_format = {};
                external_lib = {};
            end
        end
        
        extNode = get_Lookup_nD_Dynamic_wrapper(blkParams,inputs,...
            preLookUpExtNode,interpolationExtNode)
        
        function code = get_direct_method_above_using_coords(...
                index_node,coords_node, coords_input,dimension, blkParams, epsilon)
            % if coordinate at lower boundary node then use lower
            % node, else use higher node
            if  isempty(epsilon)
                condition =  ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    coords_node{dimension,1},...
                    coords_input{dimension}, []);
            else
                
                condition =  ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    coords_node{dimension,1},...
                    coords_input{dimension}, [], ...
                    LusBackendType.isLUSTREC(blkParams.lus_backend), ...
                    epsilon);
            end
            code = nasa_toLustre.lustreAst.LustreEq(...
                blkParams.sol_subs_for_dim{dimension}, ...
                nasa_toLustre.lustreAst.IteExpr(...
                condition,index_node{dimension,1},index_node{dimension,2}));
        end
        
        
        function code = get_direct_method_flat_using_coords(blkParams,...
                index_node,coords_node, coords_input,dimension,epsilon)
            if  isempty(epsilon)
                condition =  ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    coords_input{dimension},coords_node{dimension,2},[], ...
                    LusBackendType.isLUSTREC(blkParams.lus_backend));
            else
                condition =  ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    coords_input{dimension},coords_node{dimension,2},...
                    [], LusBackendType.isLUSTREC(blkParams.lus_backend),...
                    epsilon);
            end
            
            code = nasa_toLustre.lustreAst.LustreEq(...
                blkParams.sol_subs_for_dim{dimension}, nasa_toLustre.lustreAst.IteExpr(...
                condition,index_node{dimension,2},index_node{dimension,1}));
        end
        
        function code = get_direct_method_flat_using_fraction(blkParams,...
                index_node,fraction,k_index,dimension,epsilon)
            
            tableSize = blkParams.TableDim;
            numBreakpoints_minus_1 = tableSize(dimension) -1;  % 1 for 0 based to 1 based
            numBreakpoints_minus_2 = tableSize(dimension) -2;  % another 1 for lower node
            
            cond_f_GTE_1 =  ...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                fraction{dimension},...
                nasa_toLustre.lustreAst.RealExpr(1.),...
                [], LusBackendType.isLUSTREC(blkParams.lus_backend),...
                epsilon);
            
            cond_k_GTE_numBreakp_less_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                k_index{dimension},...
                nasa_toLustre.lustreAst.IntExpr(numBreakpoints_minus_1));
            
            cond_k_GTE_numBreakp_less_2 = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                k_index{dimension},...
                nasa_toLustre.lustreAst.IntExpr(numBreakpoints_minus_2));
            
            if strcmp(blkParams.ValidIndexMayReachLast, 'on')
                condition_for_extrap = cond_k_GTE_numBreakp_less_1;
            else
                condition_for_extrap = ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.AND, ...
                    cond_f_GTE_1,...
                    cond_k_GTE_numBreakp_less_2);
            end
            
            code = nasa_toLustre.lustreAst.LustreEq(...
                blkParams.sol_subs_for_dim{dimension}, ...
                nasa_toLustre.lustreAst.IteExpr(...
                condition_for_extrap,index_node{dimension,2},...
                index_node{dimension,1}));
        end
        
        
        function code = get_direct_method_clip_using_fraction(blkParams,...
                index_node,fraction,dimension,epsilon)
            
            code = nasa_toLustre.lustreAst.LustreEq(...
                blkParams.sol_subs_for_dim{dimension}, ...
                index_node{dimension,1});
            
            
        end
        
        function code = get_direct_method_nearest_using_fraction(...
                blkParams,index_node,fraction,k_index,dimension,epsilon)
            
            tableSize = blkParams.TableDim;
            numBreakpoints_minus_1 = tableSize(dimension) -1;  % 1 for 0 based to 1 based
            numBreakpoints_minus_2 = tableSize(dimension) -2;  % another 1 for lower node
            
            conds = cell(1,2);
            thens = cell(1,3);
            cond_f_GTE_1 =  ...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                fraction{dimension},...
                nasa_toLustre.lustreAst.RealExpr(1.),...
                [], LusBackendType.isLUSTREC(blkParams.lus_backend),...
                epsilon);
            cond_k_EQ_numBreakp_less_2 = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.EQ, ...
                k_index{dimension},...
                nasa_toLustre.lustreAst.IntExpr(numBreakpoints_minus_2));
            
            cond_k_GTE_numBreakp_less_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                k_index{dimension},...
                nasa_toLustre.lustreAst.IntExpr(numBreakpoints_minus_1));
            
            condition1_for_extrap = ...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.AND, ...
                cond_f_GTE_1,...
                cond_k_EQ_numBreakp_less_2);
            
            conds{1} = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.OR,...
                condition1_for_extrap, cond_k_GTE_numBreakp_less_1);
            
            thens{1} = index_node{dimension,2};
            
            conds{2} =  ...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                fraction{dimension},...
                nasa_toLustre.lustreAst.RealExpr(0.5), [], ...
                LusBackendType.isLUSTREC(blkParams.lus_backend),...
                epsilon);
            thens{2} = index_node{dimension,1};
            thens{3} = index_node{dimension,2};
            
            if strcmp(blkParams.ValidIndexMayReachLast, 'on')
                code = nasa_toLustre.lustreAst.LustreEq(...
                    blkParams.sol_subs_for_dim{dimension}, ...
                    nasa_toLustre.lustreAst.IteExpr.nestedIteExpr(conds, thens));
            else
                code = nasa_toLustre.lustreAst.LustreEq(...
                    blkParams.sol_subs_for_dim{dimension}, ...
                    nasa_toLustre.lustreAst.IteExpr(conds{2}, thens{2}, thens{3}));
            end
            
        end
        
        function code = get_direct_method_above_using_fraction(blkParams,...
                index_node,fraction,dimension)
            % if coordinate at lower boundary node then use lower
            % node, else use higher node
            condition =  ...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GT, ...
                fraction{dimension},...
                nasa_toLustre.lustreAst.RealExpr(0.), [], ...
                LusBackendType.isLUSTREC(lus_backend));
            code = nasa_toLustre.lustreAst.LustreEq(...
                blkParams.sol_subs_for_dim{dimension}, ...
                nasa_toLustre.lustreAst.IteExpr(...
                condition,index_node{dimension,1},index_node{dimension,2}));
        end
        
        function [curVars,curBody] = get_direct_method_nearest_using_coords(...
                index_node,coords_node, coords_input,dimension,...
                blkParams,epsilon)
            % 'Nearest' case, the closest bounding node for each dimension
            % is used.
            curVars = cell(1,2);
            curBody = cell(1,3);
            disFromTableNode{1} = ...
                nasa_toLustre.lustreAst.VarIdExpr(...
                sprintf('disFromTableNode_dim_%d_1',dimension));
            curVars{1} = nasa_toLustre.lustreAst.LustreVar(...
                disFromTableNode{1},'real');
            disFromTableNode{2} = ...
                nasa_toLustre.lustreAst.VarIdExpr(...
                sprintf('disFromTableNode_dim_%d_2',dimension));
            curVars{2} = nasa_toLustre.lustreAst.LustreVar(...
                disFromTableNode{2},'real');
            curBody{1} = nasa_toLustre.lustreAst.LustreEq(...
                disFromTableNode{1},...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.MINUS,...
                coords_input{dimension},coords_node{dimension,1}));
            curBody{2} = nasa_toLustre.lustreAst.LustreEq(...
                disFromTableNode{2},...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.MINUS,...
                coords_node{dimension,2},coords_input{dimension}));
            if  isempty(epsilon)
                condition =  ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                    disFromTableNode{1},...
                    disFromTableNode{2}, [], ...
                    LusBackendType.isLUSTREC(blkParams.lus_backend));
            else
                condition =  ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                    disFromTableNode{1},...
                    disFromTableNode{2}, [], ...
                    LusBackendType.isLUSTREC(blkParams.lus_backend),...
                    epsilon);
            end
            
            curBody{3} = nasa_toLustre.lustreAst.LustreEq(...
                blkParams.sol_subs_for_dim{dimension}, ...
                nasa_toLustre.lustreAst.IteExpr(...
                condition,index_node{dimension,1},...
                index_node{dimension,2}));
        end
        
    end
    
end

