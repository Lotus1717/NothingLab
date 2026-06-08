from app.services.passage_similarity import is_too_similar, overlap_ratio


def test_overlap_ratio_detects_near_duplicate():
    a = "这是第一段书摘内容，讲述主人公在清晨醒来时的所思所想。" * 3
    b = "这是第一段书摘内容，讲述主人公在清晨醒来时的所思所想。" * 3
    assert overlap_ratio(a, b) >= 0.9


def test_overlap_ratio_allows_different_passages():
    a = "第一段讲述战争爆发前的平静生活，人们在街角闲聊。"
    b = "多年以后，面对行刑队，奥雷里亚诺上校将会回想起父亲带他去见识冰块的那个遥远的下午。"
    assert overlap_ratio(a, b) < 0.52


def test_is_too_similar_with_exclude_list():
    prior = "已经展示过的段落内容" * 10
    similar = prior + "，只改了几个字"
    different = "完全不同的章节，讨论宇宙黑暗森林法则。"
    assert is_too_similar(similar, [prior])
    assert not is_too_similar(different, [prior])
