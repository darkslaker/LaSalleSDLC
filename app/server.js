const express = require('express');
const app = express();
const port = 9090;

app.get('/', (req, res) => {
  const userInput = req.query.input;
  res.send(`You entered: ${userInput}`);
});

app.listen(port, () => {
  console.log(`Vulnerable app listening on port ${port}`);
});
