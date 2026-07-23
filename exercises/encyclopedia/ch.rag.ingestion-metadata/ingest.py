def broken_ingest(source: dict[str, object]) -> dict[str, object]:
    # 练习缺口：只复制正文，ACL和来源在派生记录中丢失。
    return {"document_id": source["document_id"], "text": source["text"]}
