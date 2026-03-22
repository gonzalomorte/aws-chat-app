package pl.edu.pwr.chat.dto

import java.time.LocalDateTime

data class MessageTO(
    val username: String,
    val message: String,
    val timestamp:LocalDateTime
)
