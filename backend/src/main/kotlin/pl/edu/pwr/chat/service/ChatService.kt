package pl.edu.pwr.chat.service

import pl.edu.pwr.chat.dto.MessageRequestTO
import pl.edu.pwr.chat.dto.MessagesListTO
import java.time.LocalDateTime

interface ChatService {

    fun getAllEvents(username: String): MessagesListTO

    fun getNewMessages(username: String, after: LocalDateTime): MessagesListTO

    fun createLiveEvent(messageDTO: MessageRequestTO)

}