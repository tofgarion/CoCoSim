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
function contractBody = getContractBody(blkParams,inputs,outputs)

%
    contractBody = {};
    % y is bounded when there is no extrapolation
    if blkParams.yIsBounded
        contractBody{end+1} = ...
            nasa_toLustre.lustreAst.ContractGuaranteeExpr('', ...
            nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.AND, ...
            nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
            outputs{1},...
            nasa_toLustre.lustreAst.RealExpr(blkParams.tableMin)), ...
            nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
            outputs{1},...
            nasa_toLustre.lustreAst.RealExpr(blkParams.tableMax))));
    else
        % if u is inside boundary polytop, then y is also
        % bounded by table min and max
        terms = cell(1,2*numel(inputs));
        counter = 0;
        for i=1:numel(inputs)
            counter = counter + 1;
            terms{counter} = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                inputs{i}{1},...
                nasa_toLustre.lustreAst.RealExpr(...
                min(blkParams.BreakpointsForDimension{i})));
            counter = counter + 1;
            terms{counter} = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                inputs{i}{1},nasa_toLustre.lustreAst.RealExpr(...
                max(blkParams.BreakpointsForDimension{i})));
        end
        P = nasa_toLustre.lustreAst.BinaryExpr.BinaryMultiArgs(...
            nasa_toLustre.lustreAst.BinaryExpr.AND,terms);
        
        Q = nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.AND,...
            nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
            outputs{1},...
            nasa_toLustre.lustreAst.RealExpr(blkParams.tableMin)),...
            nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
            outputs{1},...
            nasa_toLustre.lustreAst.RealExpr(blkParams.tableMax)));
        contractBody{end+1} = ...
            nasa_toLustre.lustreAst.ContractGuaranteeExpr('', ...
            nasa_toLustre.lustreAst.BinaryExpr(...
            nasa_toLustre.lustreAst.BinaryExpr.IMPLIES,...
            P,...
            Q));
    end
    
    % contract for each element in total mesh
    if blkParams.NumberOfTableDimensions == 1
        for i=1:numel(blkParams.BreakpointsForDimension{1})-1
            curTable = [];
            curTable(1) = blkParams.Table(1,i);
            curTable(2) = blkParams.Table(1,i+1);
            P = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.AND,...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                inputs{1},...
                nasa_toLustre.lustreAst.RealExpr(...
                blkParams.BreakpointsForDimension{1}(i))),...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                inputs{1},...
                nasa_toLustre.lustreAst.RealExpr(...
                blkParams.BreakpointsForDimension{1}(i+1))));
            Q = nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.AND,...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                outputs{1},...
                nasa_toLustre.lustreAst.RealExpr(min(curTable))),...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                outputs{1},...
                nasa_toLustre.lustreAst.RealExpr(max(curTable))));
            contractBody{end+1} = ...
                nasa_toLustre.lustreAst.ContractGuaranteeExpr('', ...
                nasa_toLustre.lustreAst.BinaryExpr(...
                nasa_toLustre.lustreAst.BinaryExpr.IMPLIES,P,Q));
            
        end
    elseif blkParams.NumberOfTableDimensions == 2
        for i=1:numel(blkParams.BreakpointsForDimension{1})-1
            for j=1:numel(blkParams.BreakpointsForDimension{2})-1
                curTable = [];
                curTable(1) = blkParams.Table(i,j);
                curTable(2) = blkParams.Table(i,j+1);
                curTable(3) = blkParams.Table(i+1,j);
                curTable(4) = blkParams.Table(i+1,j+1);
                P1_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    inputs{1}{1},...
                    nasa_toLustre.lustreAst.RealExpr(...
                    blkParams.BreakpointsForDimension{1}(i)));   % dim 1 lower
                P1_2 =   nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                    inputs{1}{1},...
                    nasa_toLustre.lustreAst.RealExpr(...
                    blkParams.BreakpointsForDimension{1}(i+1)));   % dim 1 upper
                P2_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    inputs{2}{1},...
                    nasa_toLustre.lustreAst.RealExpr(...
                    blkParams.BreakpointsForDimension{2}(j))); % dim 2 lower
                P2_2 = nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                    inputs{2}{1},...
                    nasa_toLustre.lustreAst.RealExpr(...
                    blkParams.BreakpointsForDimension{2}(j+1)));   %dim 2 upper
                
                P = nasa_toLustre.lustreAst.BinaryExpr.BinaryMultiArgs(...
                    nasa_toLustre.lustreAst.BinaryExpr.AND,...
                    {P1_1, P1_2, P2_1, P2_2});
                Q = nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.AND,...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                    outputs{1},...
                    nasa_toLustre.lustreAst.RealExpr(min(curTable))),...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                    outputs{1},...
                    nasa_toLustre.lustreAst.RealExpr(max(curTable))));
                
                contractBody{end+1} = ...
                    nasa_toLustre.lustreAst.ContractGuaranteeExpr('', ...
                    nasa_toLustre.lustreAst.BinaryExpr(...
                    nasa_toLustre.lustreAst.BinaryExpr.IMPLIES,...
                    P,Q));
            end
        end
    elseif blkParams.NumberOfTableDimensions == 3
        curTable = [];
        terms = {};
        for i=1:numel(blkParams.BreakpointsForDimension{1})-1
            for j=1:numel(blkParams.BreakpointsForDimension{2})-1
                for k=1:numel(blkParams.BreakpointsForDimension{3})-1
                    curTable = [];
                    curTable(1) = blkParams.Table(i,j,k);
                    curTable(2) = blkParams.Table(i,j+1,k);
                    curTable(3) = blkParams.Table(i+1,j,k);
                    curTable(4) = blkParams.Table(i+1,j+1,k);
                    curTable(5) = blkParams.Table(i,j,k+1);
                    curTable(6) = blkParams.Table(i,j+1,k+1);
                    curTable(7) = blkParams.Table(i+1,j,k+1);
                    curTable(8) = blkParams.Table(i+1,j+1,k+1);
                    
                    P1_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                        inputs{1}{1},...
                        nasa_toLustre.lustreAst.RealExpr(...
                        blkParams.BreakpointsForDimension{1}(i)));   % dim 1 lower
                    P1_2 =   nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                        inputs{1}{1},...
                        nasa_toLustre.lustreAst.RealExpr(...
                        blkParams.BreakpointsForDimension{1}(i+1)));   % dim 1 upper
                    P2_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                        inputs{2}{1},...
                        nasa_toLustre.lustreAst.RealExpr(...
                        blkParams.BreakpointsForDimension{2}(j))); % dim 2 lower
                    P2_2 = nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                        inputs{2}{1},...
                        nasa_toLustre.lustreAst.RealExpr(...
                        blkParams.BreakpointsForDimension{2}(j+1)));   %dim 2 upper
                    P3_1 = nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                        inputs{3}{1},...
                        nasa_toLustre.lustreAst.RealExpr(...
                        blkParams.BreakpointsForDimension{3}(k))); % dim 3 lower
                    P3_2 = nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                        inputs{3}{1},...
                        nasa_toLustre.lustreAst.RealExpr(...
                        blkParams.BreakpointsForDimension{3}(k+1)));   %dim 3 upper
                    
                    P = nasa_toLustre.lustreAst.BinaryExpr.BinaryMultiArgs(...
                        nasa_toLustre.lustreAst.BinaryExpr.AND,...
                        {P1_1, P1_2, P2_1, P2_2, P3_1, P3_2});
                    Q = nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.AND,...
                        nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.GTE, ...
                        outputs{1},...
                        nasa_toLustre.lustreAst.RealExpr(min(curTable))),...
                        nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.LTE, ...
                        outputs{1},...
                        nasa_toLustre.lustreAst.RealExpr(max(curTable))));
                    contractBody{end+1} = ...
                        nasa_toLustre.lustreAst.ContractGuaranteeExpr('', ...
                        nasa_toLustre.lustreAst.BinaryExpr(...
                        nasa_toLustre.lustreAst.BinaryExpr.IMPLIES,...
                        P,...
                        Q));
                end
            end
        end                
    else
        display_msg(sprintf(...
            'More than 3 dimensions is not supported for contract in block %s',...
            HtmlItem.addOpenCmd(blk.Origin_path)), MsgType.ERROR, ...
            'Lookup_nD_To_Lustre', '');
    end
end

