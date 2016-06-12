skynet的每个service是通过内部消息进行通讯的  
对于网络消息，作者的建议是使用一个 gate(网关服务)，将网络消息翻译成 skynet内部消息再转发给对应的service处理  
有以下三种做法  
  
做法1 - watchdog 模式  
启动一个服务gate无条件将所有消息(包括连接、断开消息的控制消息)都转化成 skynet内部消息 并发送到 另一个服务 agent 进行处理  
这里的 gate 跟 agent 是一对多的关系  
  
做法2 - agent 模式  
在做法1的基础上，gate除了控制消息(连接、断开)会转化成 skynet内部消息外,   
数据包消息(socket_message)则通过 skynet.redirect(),  
转发到另一个服务 agent 上进行处理( skynet.redirect api不会进行 pack打包操作, 可以减少一定的开销 ),  
这里的 gate 跟 agent 是一对多的关系  
  
做法3 - broker 模式  
跟做法2类似, 但gate 对于数据包消息(socket_message)都统一转发到另一个服务 broker 上进行处理  
这里的 gate 跟 broker 是一对一的关系  
  
gate责职:  
1. 监听一个 TCP 端口  
2. 接受和断开连入的 TCP 连接  
3. 把连接上获得的数据转发到skynet内部另一个服务去处理，它自己不做数据处理是因为我们需要保持 gate 实现的简洁高效。  
4. 负责按约定好的协议，把 TCP 连接上的数据流切分成一个个的包，而不需要业务处理服务来分割 TCP 数据流。  
(注意，Gate 只负责读取外部数据，但不负责回写。也就是说，向这些连接发送数据不是它的职责范畴。)  
  
watchdog责职:  
1. 用户认证过程  
2. 给通过认证的用户创建agent  
(当然以上的逻辑也可以在gate进行处理, 但为了保持 gate 实现的简洁高效, 还是把它抽离到watchdog实现)  
  
reference:  
[1] http://blog.codingnow.com/2012/09/the_design_of_skynet.html  
[2] https://github.com/cloudwu/skynet/wiki/GettingStarted  
[3] https://groups.google.com/forum/#!topic/skynet-users/GTruUtEzD0Q  
  
作为示范，skynet 开源项目实现了一个简单的回写代理服务，叫做 service_client 。  
启动这个服务，启动时绑定一个 fd ，发送给这个服务的消息包，都会被加上两字节的长度包头，写给对应的 fd 。  
根据不同的分包协议，可以自己定制不同的 client 服务来解决向外部连接发送数据的模块。  
  
  
  
