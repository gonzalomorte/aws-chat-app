package pl.edu.pwr.chat.service

import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import pl.edu.pwr.chat.dto.MessageRequestTO
import pl.edu.pwr.chat.dto.MessageTO
import pl.edu.pwr.chat.dto.MessagesListTO
import pl.edu.pwr.chat.model.ChatMessage
import pl.edu.pwr.chat.repository.ChatMessageRepository
import java.time.LocalDateTime

@Service
class ChatServiceImpl @Autowired constructor(

    private val chatMessageRepository: ChatMessageRepository

) : ChatService {
    override fun getAllEvents(username: String): MessagesListTO {
        val messages = chatMessageRepository.findAll()
        val messageList = messages.map { msg ->
            MessageTO(
                username = msg.username,
                message = msg.message,
                timestamp = msg.timestamp
            )
        }
        return MessagesListTO(messages = messageList)
    }

    override fun getNewMessages(username: String, after: LocalDateTime): MessagesListTO {
        val messages = chatMessageRepository.findByTimestampAfter(after)
        val messageList = messages.map { msg ->
            MessageTO(
                username = msg.username,
                message = msg.message,
                timestamp = msg.timestamp
            )
        }
        return MessagesListTO(messages = messageList)
    }

    override fun createLiveEvent(messageDTO: MessageRequestTO) {
        val chatMessage = ChatMessage(
            username = messageDTO.username,
            message = messageDTO.message,
            timestamp = LocalDateTime.now()
        )

        chatMessageRepository.save(chatMessage)
    }

}
