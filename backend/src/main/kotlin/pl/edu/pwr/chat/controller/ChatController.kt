package pl.edu.pwr.chat.controller

import org.springframework.beans.factory.annotation.Autowired
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import pl.edu.pwr.chat.dto.MessageRequestTO
import pl.edu.pwr.chat.dto.MessagesListTO
import pl.edu.pwr.chat.service.ChatService
import java.time.LocalDateTime


@RestController
@RequestMapping("chat")
class ChatController @Autowired constructor(
    private val chatService: ChatService
) {

    @GetMapping("all")
    fun getAllMessages(@RequestParam username: String): ResponseEntity<Any> {
        val resultTO: MessagesListTO = chatService.getAllEvents(username)

        return ResponseEntity.ok(resultTO)
    }


    @GetMapping
    fun getNewMessages(@RequestParam username: String, @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) after: LocalDateTime): ResponseEntity<Any> {
        val resultTO: MessagesListTO = chatService.getNewMessages(username, after)

        return ResponseEntity.ok(resultTO)
    }

    @PostMapping
    fun createLiveEvent(@RequestBody messageDTO: MessageRequestTO): ResponseEntity<Any> {
        chatService.createLiveEvent(messageDTO)

        return ResponseEntity.ok().build()
    }
}