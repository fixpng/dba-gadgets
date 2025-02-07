CREATE OR REPLACE TYPE t_varchar2_tab AS TABLE OF VARCHAR2(32767); -- 定义一个VARCHAR2类型的表，用于存放分割后的字符串

CREATE OR REPLACE FUNCTION f_str_split (
    p_str IN CLOB,          -- 输入的原始字符串
    p_delimiter IN VARCHAR2 -- 分隔符
) RETURN t_varchar2_tab PIPELINED -- 返回类型为前面定义的t_varchar2_tab类型
IS
    l_str   CLOB := p_str || p_delimiter; -- 在原字符串末尾添加分隔符以确保最后一个元素也能被处理
    l_n     NUMBER;
    l_pos   NUMBER := 1;
BEGIN
    LOOP
        l_n := INSTR(l_str, p_delimiter, l_pos); -- 查找分隔符的位置
        EXIT WHEN nvl(l_n, 0) = 0; -- 如果找不到分隔符，则退出循环
        PIPE ROW(SUBSTR(l_str, l_pos, l_n - l_pos)); -- 截取子串并输出
        l_pos := l_n + LENGTH(p_delimiter); -- 更新起始位置到下一个元素的开头
    END LOOP;
    RETURN;
END f_str_split;