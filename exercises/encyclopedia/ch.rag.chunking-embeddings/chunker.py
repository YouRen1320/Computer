def broken_chunks(document: dict[str, object]) -> list[dict[str, object]]:
    # 练习缺口：子记录只留正文，父ID和ACL都丢失。
    return [{"chunk_id": f"c-{index}", "text": text} for index, text in enumerate(document["paragraphs"])]
