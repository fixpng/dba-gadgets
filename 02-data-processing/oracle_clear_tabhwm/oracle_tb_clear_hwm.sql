CREATE TABLE tb_clear_hwm (
    batchno        VARCHAR2(8) NOT NULL,          -- 批次号，格式为 yyyymmdd
    tabname        VARCHAR2(128) NOT NULL,        -- 表名
    status         VARCHAR2(1) DEFAULT '0' NOT NULL, -- 状态，默认为 '0'
    is_parttab     NUMBER(1) NOT NULL,            -- 是否分区表，1 是，0 否
    current_size   NUMBER(10, 2),                 -- 当前大小（MB）
    real_size      NUMBER(10, 2),                 -- 实际使用大小（MB）
    hwm_size       NUMBER(10, 2),                 -- 高水位标记大小（MB）
    rate           VARCHAR2(10),                  -- 使用率百分比
    loadtime       DATE DEFAULT SYSDATE NOT NULL, -- 记录加载时间
    CONSTRAINT pk_tb_clear_hwm PRIMARY KEY (batchno, tabname) -- 复合主键
);

CREATE INDEX idx_tb_clear_hwm_batchno ON tb_clear_hwm(batchno);
CREATE INDEX idx_tb_clear_hwm_status ON tb_clear_hwm(status);
CREATE INDEX idx_tb_clear_hwm_is_parttab ON tb_clear_hwm(is_parttab);