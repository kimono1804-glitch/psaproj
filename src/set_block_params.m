function set_block_params(blk, varargin)
%SET_BLOCK_PARAMS Set block parameters by name, checking they are real.
%   Fails if the block has no such dialog parameter. Value parameters
%   (not *_unit) must also be visible after setting, because a hidden
%   parameter would be ignored by the block.
dp = get_param(blk, 'DialogParameters');
mo = get_param(blk, 'MaskObject');
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~isfield(dp, name)
        error('set_block_params:param', 'Block "%s" has no parameter "%s".', ...
            strrep(blk, newline, ' '), name);
    end
    set_param(blk, name, varargin{k+1});
    if ~isempty(mo) && ~endsWith(name, '_unit')
        P = mo.getParameter(name);
        if ~isempty(P) && strcmp(P.Visible, 'off')
            error('set_block_params:hidden', ...
                'Parameter "%s" of "%s" is hidden, so it would be ignored.', ...
                name, strrep(blk, newline, ' '));
        end
    end
end
end
