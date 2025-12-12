# Use official Python image
FROM python:3.10-slim

# Create a non-root user (appuser)
RUN useradd -m appuser

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency file first (better caching)
COPY requirements.txt .

# Install Python deps BEFORE switching users
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files into container
COPY . .

# Change ownership of app files
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose Django/Gunicorn port
EXPOSE 5000

# Start Django app with Gunicorn
CMD ["gunicorn", "sample.wsgi:application", "--bind", "0.0.0.0:5000"]
