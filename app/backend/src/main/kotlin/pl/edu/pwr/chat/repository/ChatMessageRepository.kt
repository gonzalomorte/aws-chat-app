package pl.edu.pwr.chat.repository

import org.springframework.data.jpa.repository.JpaRepository
import pl.edu.pwr.chat.model.ChatMessage
import java.time.LocalDateTime

interface ChatMessageRepository : JpaRepository<ChatMessage, Long> {
    fun findByTimestampAfter(timestamp: LocalDateTime): List<ChatMessage>
}