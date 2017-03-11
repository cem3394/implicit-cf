This project contains two recommenders, a simpler one based on a k Nearest Neighbors approach using Jaccard distance, and a more involved low-rank matrix factorization (MF) approach based on the method of Hu, Koren, and Volinsky in [Collaborative Filtering for Implicit Feedback Datasets](http://yifanhu.net/PUB/cf.pdf) (there is also an excellent exposition by the Activision data science team [here](http://activisiongamescience.github.io/2016/01/11/Implicit-Recommender-Systems-Biased-Matrix-Factorization)). The code for both can be found in `src/KNearestNeighbors.hs` and `src/MatrixFactorization.hs`. The MF code also relies on a bias model `src/Bias.hs` to account for user and item biases (see the Activision post above), this part is still experimental and the bias factor is zeroed out at the moment.
 

Both models were scored against holdout transaction data from `data/trx_data.csv` using a rudimentary click-through-rate type scorer in `test/Exec.hs`. The oldout data files were constructed using shell tools (e.g. `sed`,`split` etc). Since my goal here was to demonstrate solid programming skills, I thought this approach sufficient for a baseline comparison (I used more traditional validation techniques and metrics in the Jupyter notebook). Similarly I settled on a simple Jaccard metric rather than some other metric (e.g. Pearson, cosine etc) for the KNN model, and stochastic gradient descent rather than alternating least squares for the MF model. This led to simpler code and I believe demonstrates good applied math procedure (i.e. create baselines using elementary methods).

The main function, along with a few unit tests can be found in `test/Spec.hs`. The `data` folder contains the recommedation files for both solutions.
