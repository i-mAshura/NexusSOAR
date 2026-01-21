#!/bin/bash

# Catalyst Token Retriever
# Retrieves a fresh bearer token from Catalyst (PocketBase)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Catalyst Token Retriever (PocketBase)     ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo ""

# Default credentials
DEFAULT_EMAIL="admin@catalyst.local"
DEFAULT_PASSWORD="admin123"
CATALYST_URL="http://localhost:8090"

# Check if Catalyst is running
if ! curl -s "${CATALYST_URL}/" > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Cannot connect to Catalyst at ${CATALYST_URL}${NC}"
    echo "   Make sure Catalyst is running."
    exit 1
fi

# Prompt for credentials (or use defaults)
echo -e "${YELLOW}Press Enter to use defaults, or enter custom credentials:${NC}"
echo ""

read -p "Email [$DEFAULT_EMAIL]: " EMAIL
EMAIL=${EMAIL:-$DEFAULT_EMAIL}

read -sp "Password [$DEFAULT_PASSWORD]: " PASSWORD
PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
echo ""
echo ""

echo -e "${BLUE}→ Attempting authentication...${NC}"

# Method 1: Try PocketBase Admin Auth
echo "   Trying admin endpoint..."
ADMIN_RESPONSE=$(curl -s -X POST "${CATALYST_URL}/api/admins/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" 2>/dev/null)

TOKEN=$(echo "$ADMIN_RESPONSE" | jq -r .token 2>/dev/null)

# Method 2: Try PocketBase Users Collection Auth
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "   Trying users collection endpoint..."
    USER_RESPONSE=$(curl -s -X POST "${CATALYST_URL}/api/collections/users/auth-with-password" \
      -H "Content-Type: application/json" \
      -d "{\"identity\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" 2>/dev/null)
    
    TOKEN=$(echo "$USER_RESPONSE" | jq -r .token 2>/dev/null)
fi

echo ""

# Display Results
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║            ❌ AUTHENTICATION FAILED            ║${NC}"
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  • Incorrect username or password"
    echo "  • User does not exist"
    echo "  • Catalyst not fully initialized"
    echo ""
    echo "Try creating the user first in Catalyst UI:"
    echo "  ${CATALYST_URL}"
    exit 1
fi

# Success!
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ✅ TOKEN RETRIEVED!                  ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${BLUE}Your Bearer Token:${NC}"
echo ""
echo -e "${YELLOW}${TOKEN}${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Display token info if available
if command -v jq &> /dev/null; then
    # Try to decode JWT (basic)
    PAYLOAD=$(echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq . 2>/dev/null)
    if [ -n "$PAYLOAD" ]; then
        echo -e "${BLUE}Token Information:${NC}"
        echo "$PAYLOAD" | jq -r '.exp' | xargs -I {} date -d @{} "+  Expires: %Y-%m-%d %H:%M:%S" 2>/dev/null || echo "  Expires: (could not decode)"
        echo ""
    fi
fi

# Instructions
echo -e "${BLUE}How to Update in n8n:${NC}"
echo ""
echo "1. Open n8n: http://localhost:5678"
echo "2. Go to: Settings → Credentials"
echo "3. Click: 'Bearer Auth account' (or your Catalyst credential)"
echo "4. Paste the token above in the 'Token' field"
echo "5. Click: Save"
echo ""
echo -e "${GREEN}Done! Your n8n workflow will now use the fresh token.${NC}"
echo ""

# Save to file option
read -p "Save token to file? (y/N): " SAVE_FILE
if [[ "$SAVE_FILE" =~ ^[Yy]$ ]]; then
    TOKEN_FILE="catalyst_token_$(date +%Y%m%d_%H%M%S).txt"
    echo "$TOKEN" > "$TOKEN_FILE"
    echo -e "${GREEN}✅ Token saved to: $TOKEN_FILE${NC}"
    echo ""
fi

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
