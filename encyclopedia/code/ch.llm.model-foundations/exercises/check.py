from budget import fits_context

# 目标Tokenizer的已记录结果可以比可见字符更多；不能用 len(text) 替代。
text = "工单"
recorded_token_count = 6
limit = 7
output_reserve = 2
assert not fits_context(text, limit - output_reserve), (
    f"context budget must use recorded tokenizer count {recorded_token_count} plus output reserve, not character length"
)
