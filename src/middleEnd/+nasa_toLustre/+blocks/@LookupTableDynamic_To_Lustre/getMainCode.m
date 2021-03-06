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
function [mainCode, main_vars] = getMainCode(obj, blk,outputs,inputs,...
    wrapperExtNode,blkParams)

%    % LookupTableDynamic_To_Lustre
    
    outputDataType = blk.CompiledPortDataTypes.Outport{1};
    lus_out_type =...
        nasa_toLustre.utils.SLX2LusUtils.get_lustre_dt(outputDataType);
    % if outputDataType is not real, we need to cast outputs   
    [output_conv_format, external_lib]  = ...
        nasa_toLustre.blocks.Lookup_nD_To_Lustre.get_output_conv_format(...
        blk,blkParams);
    if ~isempty(external_lib)
        obj.addExternal_libraries(external_lib);
    end      

    main_vars = cell(1,numel(outputs));
       
    % mainCode
    mainCode = cell(1, numel(outputs));
    for outIdx=1:numel(outputs)
        main_vars{outIdx} = ...
            nasa_toLustre.lustreAst.LustreVar(outputs{outIdx}, lus_out_type);
        
        nodeCall_inputs = cell(1,1+numel(inputs{2})+numel(inputs{3}));

        nodeCall_inputs{1} = inputs{1}{outIdx};
        counter = 1;
        for i=2:numel(inputs)
            for j=1:numel(inputs{i})
                counter = counter + 1;
                nodeCall_inputs{counter} = inputs{i}{j};
            end
        end
        if isempty(output_conv_format)
            mainCode{outIdx} = nasa_toLustre.lustreAst.LustreEq(...
                outputs{outIdx}, nasa_toLustre.lustreAst.NodeCallExpr(...
                wrapperExtNode.name, nodeCall_inputs));
        else
            % if outputDataType is not real, we need to cast outputs
            mainCode{outIdx} = nasa_toLustre.lustreAst.LustreEq(...
                outputs{outIdx}, ...
                nasa_toLustre.utils.SLX2LusUtils.setArgInConvFormat(...
                output_conv_format, ...
                nasa_toLustre.lustreAst.NodeCallExpr(...
                wrapperExtNode.name, nodeCall_inputs)));            
        end  
    end  
    
end
