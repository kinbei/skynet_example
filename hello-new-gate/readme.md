
socket_proxyd 是一个全局的唯一服务
提供了文本的协议
1. CLOSED
2. SUCC
3. FAIL



#知识点
1. skynet.info_func( function() return xxx end )  
-- 注册 info 函数，便于 debug 指令 INFO 查询。  

2. int skynet_send(struct skynet_context * context, uint32_t source, uint32_t destination , int type, int session, void * msg, size_t sz);  
-- 类似于lua api: skynet.send() source为源地址, 通常为0表示本service, destination表示目标地址
