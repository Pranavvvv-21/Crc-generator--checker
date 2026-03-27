import numpy as np
from sklearn.linear_model import LogisticRegression
import pickle

def train_error_prediction_model(num_samples=5000):
    print(f"Generating synthetic dataset with {num_samples} samples...")
    X = []
    y = []

    for _ in range(num_samples):
        # Generate 32-bit random data bits
        data = np.random.randint(0, 2, 32)
        # Generate random 16-bit CRC bits (simplified)
        crc  = np.random.randint(0, 2, 16)
        # Randomly assign error labels (0=no error, 1=error)
        error = np.random.choice([0,1])

        # Feature vector: concatenation of data bits and CRC bits
        X.append(np.concatenate([data, crc]))
        y.append(error)

    X = np.array(X)
    y = np.array(y)

    print("Training Logistic Regression model for error prediction...")
    model = LogisticRegression()
    model.fit(X, y)

    score = model.score(X, y)
    print(f"Model Training Complete. Training Accuracy: {score:.4f}")

    # Optional: Save the trained model to results folder
    # with open('../results/error_prediction_model.pkl', 'wb') as f:
    #     pickle.dump(model, f)

if __name__ == "__main__":
    train_error_prediction_model()
