# CityZen AI Assistant Setup Guide

## How to Configure Gemini AI

The CityZen app includes an AI environmental health assistant powered by Google's Gemini AI. To use this feature, you need to configure your own Gemini API key.

### Step 1: Get Your Gemini API Key

1. Visit [Google AI Studio API Keys](https://aistudio.google.com/api-keys)
2. Sign in with your Google account
3. Click "Create API Key" 
4. Copy the API key (it starts with "AIza...")

### Step 2: Configure the API Key in CityZen

1. Open the CityZen app in your browser (http://localhost:8085)
2. Log in or register an account
3. Navigate to the **Settings** page (bottom navigation)
4. Find the **AI Assistant** section
5. Tap on **AI Configuration**
6. Paste your Gemini API key in the dialog
7. Click **Save**

### Step 3: Test the AI Assistant

1. Go to the **AI Chat** page (bottom navigation)
2. Try asking questions like:
   - "What's the air quality like today?"
   - "Should I exercise outdoors right now?"
   - "Give me health advice based on current conditions"

### API Key Security

- Your API key is stored locally in your browser
- The key is only used to communicate with Google's Gemini API
- Never share your API key with others

### Troubleshooting

**AI Chat shows "not configured" message:**
- Make sure you've entered a valid Gemini API key in Settings
- The key should start with "AIza" and be longer than 20 characters

**AI responses are slow or fail:**
- Check your internet connection
- Verify your API key is correct
- Make sure you have API quota remaining in Google AI Studio

### Free Tier Limits

Google Gemini API offers a generous free tier:
- 15 requests per minute
- 1 million tokens per day
- Perfect for personal use of the CityZen app

For more information, visit the [Gemini API documentation](https://ai.google.dev/docs).