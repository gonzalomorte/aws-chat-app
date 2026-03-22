<script lang="ts">
	import { onMount, afterUpdate } from 'svelte';
	import api from '$lib/api';
	import type { Message } from '$lib/types/Message';

	let username: string = 'User' + Math.floor(Math.random() * 1000);
	let newMessage: string = '';
	let messages: Message[] = [];
	let chatContainer: HTMLDivElement;

	const scrollToBottom = () => {
		if (chatContainer) {
			chatContainer.scrollTop = chatContainer.scrollHeight;
		}
	};

	const fetchAllMessages = async () => {
		try {
			const response = await api.get('/chat/all', { params: { username } });
			messages = response.data.messages;
			scrollToBottom();
		} catch (error) {
			console.error('Error fetching all messages:', error);
		}
	};

	const fetchNewMessages = async () => {
		try {
			const lastTimestamp = messages.length
				? messages[messages.length - 1].timestamp
				: new Date(0).toISOString();
			const response = await api.get('/chat', {
				params: { username, after: lastTimestamp }
			});
			if (response.data.messages && response.data.messages.length) {
				messages = [...messages, ...response.data.messages];
				scrollToBottom();
			}
		} catch (error) {
			console.error('Error fetching new messages:', error);
		}
	};

	const sendMessage = async () => {
		if (!newMessage.trim()) return;
		try {
			await api.post('/chat', { username, message: newMessage });
			newMessage = '';
			await fetchAllMessages();
			scrollToBottom();
		} catch (error) {
			console.error('Error sending message:', error);
		}
	};

	onMount(() => {
		fetchAllMessages();
		const interval = setInterval(fetchNewMessages, 3000); // polling co 3 sekundy
		return () => clearInterval(interval);
	});

	afterUpdate(() => {
		scrollToBottom();
	});
</script>

<div class="max-w-2xl mx-auto p-4">
	<!-- Pole do zmiany nicku -->
	<div class="mb-4 flex items-center">
		<label for="username" class="font-semibold mr-2">Nickname:</label>
		<input
			id="username"
			type="text"
			autocomplete="off"
			bind:value={username}
			class="border border-gray-300 rounded px-3 py-2"
			placeholder="Enter your nickname"
		/>
	</div>

	<h1 class="text-2xl font-bold mb-4">Chat Room</h1>

	<!-- Kontener wiadomości z przypiętą referencją -->
	<div class="border border-gray-300 rounded p-4 mb-4 h-80 overflow-y-auto" bind:this={chatContainer}>
		{#each messages as msg (msg.timestamp)}
			<div class="mb-2">
				<span class="font-semibold">{msg.username}</span>
				<span class="text-sm text-gray-500 ml-2">{new Date(msg.timestamp).toLocaleTimeString()}</span>
				<p>{msg.message}</p>
			</div>
		{/each}
	</div>

	<div class="flex space-x-2">
		<input
			type="text"
			bind:value={newMessage}
			class="flex-grow border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring"
			placeholder="Type your message..."
		/>
		<button
			on:click={sendMessage}
			class="cursor-pointer bg-blue-500 hover:bg-blue-600 text-white font-semibold px-4 py-2 rounded"
		>
			Send
		</button>
	</div>
</div>
